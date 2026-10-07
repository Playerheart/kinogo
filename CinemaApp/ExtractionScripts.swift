import Foundation

enum ExtractionScripts {

    static let catalog = """
    (function() {
        try {
            var lazyImgs = document.querySelectorAll('img[data-src], img[data-original], img[data-lazy], img[data-echo]');
            for (var li = 0; li < lazyImgs.length; li++) {
                var limg = lazyImgs[li];
                var ds = limg.getAttribute('data-src') || limg.getAttribute('data-original') || limg.getAttribute('data-lazy') || limg.getAttribute('data-echo');
                if (ds && (!limg.src || limg.src.indexOf('data:') === 0 || limg.src.indexOf('placeholder') !== -1)) {
                    limg.src = ds;
                }
            }
        } catch(e) {}

        var result = [];
        var seen = {};
        var anchors = document.querySelectorAll('a[href]');

        var skipWords = ['войти', 'регистрация', 'все ', 'далее', 'назад', 'следующая',
                         'предыдущая', 'наверх', 'комментар', 'подписаться',
                         'оставить', 'перейти', 'главная', 'контакты', 'поиск', 'меню',
                         'смотреть онлайн', 'скачать'];

        for (var i = 0; i < anchors.length; i++) {
            var a = anchors[i];
            var href = a.href || '';
            if (!href) continue;
            if (href.indexOf('javascript:') === 0) continue;
            if (href.indexOf('mailto:') === 0) continue;
            if (href.indexOf('tel:') === 0) continue;
            if (href.indexOf('#') === 0) continue;

            var isFilmLink = /\\.html($|[?#])/.test(href) ||
                             /\\/\\d+-[\\w-]+/.test(href) ||
                             /\\/(film|films|movie|series|serial|mult|cartoon|dorama|anime|online)/i.test(href);
            if (!isFilmLink) continue;
            if (seen[href]) continue;

            var img = a.querySelector('img');
            if (!img) continue;

            var imgSrc = img.src || img.getAttribute('data-src') || img.getAttribute('data-original') || img.getAttribute('data-lazy') || '';
            if (!imgSrc || imgSrc.indexOf('data:') === 0) continue;
            if (imgSrc.indexOf('dot.gif') !== -1) continue;

            var w = img.naturalWidth || parseInt(img.getAttribute('width')) || 0;
            var h = img.naturalHeight || parseInt(img.getAttribute('height')) || 0;
            if (w > 0 && w < 80) continue;
            if (h > 0 && h < 80) continue;

            var title = (img.alt || '').trim();
            if (!title) {
                var titleEl = a.querySelector('[class*="title" i], [class*="name" i], [class*="caption" i]');
                if (titleEl) title = (titleEl.textContent || '').trim();
            }
            if (!title) title = (a.textContent || '').trim();
            title = title.replace(/\\s+/g, ' ').trim();

            if (!title || title.length < 2 || title.length > 250) continue;
            var lt = title.toLowerCase();
            var isSkip = false;
            for (var s = 0; s < skipWords.length; s++) {
                if (lt.indexOf(skipWords[s]) !== -1) { isSkip = true; break; }
            }
            if (isSkip) continue;

            var text = (a.textContent || '').trim();
            var ym = text.match(/\\b(19|20)\\d{2}\\b/);
            var rm = text.match(/\\b[0-9]\\.[0-9]\\b/);

            seen[href] = true;
            result.push({
                title: title.substring(0, 200),
                url: href,
                poster: imgSrc,
                year: ym ? ym[0] : '',
                rating: rm ? rm[0] : ''
            });
            if (result.length >= 200) break;
        }
        return JSON.stringify(result);
    })();
    """

    static func detail(baseHost: String) -> String {
        return """
        (function() {
            var BASE_HOST = '\(baseHost)';
            function norm(u) {
                if (!u) return '';
                u = String(u).trim();
                if (u.indexOf('//') === 0) return 'https:' + u;
                if (u.charAt(0) === '/') return 'https://' + BASE_HOST + u;
                return u;
            }

            function bgUrl(el) {
                if (!el) return '';
                try {
                    var db = el.getAttribute('data-bg');
                    if (db) return norm(db);
                    var st = el.getAttribute('style') || '';
                    var m = st.match(/url\\(["']?([^"')]+)["']?\\)/);
                    if (m) return norm(m[1]);
                } catch(e) {}
                return '';
            }

            var out = {
                title: '', poster: '', description: '',
                year: '', country: '', duration: '', genres: '',
                quality: '', voices: '',
                players: [], actors: [], related: []
            };

            var ld = null;
            try {
                var scripts = document.querySelectorAll('script[type="application/ld+json"]');
                for (var s = 0; s < scripts.length; s++) {
                    var raw = scripts[s].textContent || '';
                    if (!raw || raw.indexOf('"Movie"') === -1) continue;
                    try {
                        var parsed = JSON.parse(raw);
                        var candidates = [];
                        if (Array.isArray(parsed)) candidates = parsed;
                        else if (parsed['@graph'] && Array.isArray(parsed['@graph'])) candidates = parsed['@graph'];
                        else candidates = [parsed];
                        for (var c = 0; c < candidates.length; c++) {
                            var t = candidates[c]['@type'];
                            var isMovie = (t === 'Movie') || (Array.isArray(t) && t.indexOf('Movie') !== -1);
                            if (isMovie) { ld = candidates[c]; break; }
                        }
                        if (ld) break;
                    } catch(e) {}
                }
            } catch(e) {}

            if (ld) {
                if (ld.name) out.title = String(ld.name).trim();
                if (ld.image) {
                    var img = ld.image;
                    if (typeof img === 'string') out.poster = norm(img);
                    else if (Array.isArray(img) && img.length > 0) {
                        var first = img[0];
                        out.poster = norm(typeof first === 'string' ? first : (first.url || ''));
                    } else if (img.url) out.poster = norm(img.url);
                }
                if (ld.description) out.description = String(ld.description).trim().substring(0, 3000);
                if (ld.dateCreated) out.year = String(ld.dateCreated).trim();
                if (ld.countryOfOrigin) {
                    var co = ld.countryOfOrigin;
                    if (!Array.isArray(co)) co = [co];
                    var countries = [];
                    for (var ci = 0; ci < co.length; ci++) {
                        if (co[ci] && co[ci].name) countries.push(String(co[ci].name).trim());
                    }
                    out.country = countries.join(', ');
                }
                if (ld.genre) {
                    var g = ld.genre;
                    if (!Array.isArray(g)) g = [g];
                    out.genres = g.map(function(x){ return String(x).trim(); }).join(' / ');
                }
                if (ld.duration) {
                    var d = String(ld.duration);
                    var m = d.match(/PT(?:(\\d+)H)?(?:(\\d+)M)?/);
                    if (m) {
                        var hh = m[1] ? parseInt(m[1]) : 0;
                        var mm = m[2] ? parseInt(m[2]) : 0;
                        if (hh > 0) out.duration = hh + ' ч ' + mm + ' мин';
                        else out.duration = mm + ' мин';
                    }
                }
            }

            if (!out.title) {
                var h1 = document.querySelector('h1.article__title, h1');
                if (h1) out.title = (h1.textContent || '').trim().replace(/\\s+/g, ' ');
            }
            if (!out.poster) {
                var pi = document.querySelector('.article__poster img, .movie__poster img, .poster img');
                if (pi) out.poster = norm(pi.getAttribute('src') || pi.getAttribute('data-src') || '');
            }

            function fieldByLabel(label) {
                var items = document.querySelectorAll('.article__info > div, .ka4');
                for (var i = 0; i < items.length; i++) {
                    var t = (items[i].textContent || '').trim();
                    if (t.indexOf(label) === 0 || t.indexOf(label) !== -1) {
                        var parts = t.split(':');
                        if (parts.length > 1) return parts.slice(1).join(':').trim();
                    }
                }
                return '';
            }
            if (!out.year) out.year = fieldByLabel('Вышел в').substring(0, 4);
            if (!out.country) out.country = fieldByLabel('Сняли в');
            if (!out.duration) out.duration = fieldByLabel('Длительность');
            if (!out.genres) out.genres = fieldByLabel('Жанры');
            out.quality = fieldByLabel('Лучшее качество');
            out.voices = fieldByLabel('Озвучки для вас');

            if (!out.description) {
                var at = document.querySelector('.article__text');
                if (at) {
                    var clone = at.cloneNode(true);
                    var info = clone.querySelector('.article__info');
                    if (info) info.remove();
                    var imp = clone.querySelector('.article__text-important');
                    if (imp) imp.remove();
                    out.description = (clone.textContent || '').trim().replace(/\\s+/g, ' ').substring(0, 3000);
                }
            }

            var PLAYER_HOSTS = ['cinemar', 'kodik', 'alloha', 'bazon', 'videocdn', 'sibnet',
                                'aniboom', 'hdvb', 'vadbam', 'pleer', 'youtube', 'youtu.be'];
            function isPlayerUrl(u) {
                if (!u) return false;
                var low = u.toLowerCase();
                for (var i = 0; i < PLAYER_HOSTS.length; i++) {
                    if (low.indexOf(PLAYER_HOSTS[i]) !== -1) return true;
                }
                return false;
            }

            var seenP = {};

            var tabs = document.querySelectorAll('.js-player-tabs li[data-src], .player-tabs li[data-src]');
            for (var t = 0; t < tabs.length; t++) {
                var tab = tabs[t];
                var src = norm(tab.getAttribute('data-src') || '');
                if (!src || !isPlayerUrl(src) || seenP[src]) continue;
                seenP[src] = true;
                var tabName = (tab.textContent || '').trim() || ('Плеер ' + (out.players.length + 1));
                out.players.push({ name: tabName, url: src });
            }

            var iframes = document.querySelectorAll('iframe');
            for (var i = 0; i < iframes.length; i++) {
                var f = iframes[i];
                var src = norm(f.getAttribute('src') || '');
                if (!src) src = norm(f.getAttribute('data-src') || '');
                if (!src || seenP[src] || !isPlayerUrl(src)) continue;
                seenP[src] = true;
                var name = (f.getAttribute('title') || '').trim() || ('Плеер ' + (out.players.length + 1));
                out.players.push({ name: name, url: src });
            }

            var trailerBtn = document.querySelector('.js-player-trailer');
            if (trailerBtn) {
                var tSrc = norm(trailerBtn.getAttribute('data-src') || '');
                if (tSrc && !seenP[tSrc] && isPlayerUrl(tSrc)) {
                    seenP[tSrc] = true;
                    out.players.push({ name: 'Трейлер', url: tSrc });
                }
            }

            var seenA = {};
            var sections = document.querySelectorAll('.persons__section');
            for (var si = 0; si < sections.length; si++) {
                var section = sections[si];
                var items = section.querySelectorAll('a.js-person, a.persons__item');
                for (var ai = 0; ai < items.length; ai++) {
                    var a = items[ai];
                    var aHref = norm(a.href || '');
                    var name = (a.getAttribute('title') || '').trim();
                    if (!name) {
                        var cclone = a.cloneNode(true);
                        var fdiv = cclone.querySelector('.persons__foto');
                        if (fdiv) fdiv.remove();
                        name = (cclone.textContent || '').trim().replace(/\\s+/g, ' ');
                    }
                    if (!name || name.length > 100) continue;

                    var photo = '';
                    var fotoEl = a.querySelector('.persons__foto');
                    if (fotoEl) {
                        photo = bgUrl(fotoEl);
                        if (photo.indexOf('no_actors') !== -1 || photo.indexOf('dot.gif') !== -1) photo = '';
                    }

                    if (seenA[name]) continue;
                    seenA[name] = true;
                    out.actors.push({ name: name, photo: photo, url: aHref });
                }
            }

            var seenR = {};
            var relEls = document.querySelectorAll('.relatednews__content a.relatednews__item, a.relatednews__item');
            for (var ri = 0; ri < relEls.length; ri++) {
                var rel = relEls[ri];
                var rHref = norm(rel.href || '');
                if (!rHref || seenR[rHref]) continue;
                seenR[rHref] = true;

                var rImg = rel.querySelector('img.relatednews__image, img');
                var rPoster = '';
                if (rImg) {
                    rPoster = norm(rImg.getAttribute('data-src') || rImg.getAttribute('src') || '');
                    if (rPoster.indexOf('dot.gif') !== -1) rPoster = '';
                }

                var rTitle = (rel.getAttribute('title') || '').trim();
                if (!rTitle && rImg) rTitle = (rImg.alt || '').trim();
                if (!rTitle) {
                    var rClone = rel.cloneNode(true);
                    var rcImg = rClone.querySelector('img');
                    if (rcImg) rcImg.remove();
                    rTitle = (rClone.textContent || '').trim().replace(/\\s+/g, ' ');
                }
                if (!rTitle || rTitle.length > 200) continue;

                var rm = rTitle.match(/\\((\\d{4})\\)/);
                out.related.push({
                    title: rTitle,
                    url: rHref,
                    poster: rPoster,
                    year: rm ? rm[1] : '',
                    rating: ''
                });
                if (out.related.length >= 20) break;
            }

            return JSON.stringify(out);
        })();
        """
    }
}
