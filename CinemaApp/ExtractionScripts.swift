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

    static let detail = """
    (function() {
        function norm(u) {
            if (!u) return '';
            u = u.trim();
            if (u.indexOf('//') === 0) return 'https:' + u;
            return u;
        }

        var out = { title: '', poster: '', description: '', players: [], actors: [] };

        // === 1. JSON-LD schema.org Movie — самый надёжный источник ===
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

            // Актёры из JSON-LD (только имена)
            var ldActors = ld.actor;
            if (ldActors) {
                if (!Array.isArray(ldActors)) ldActors = [ldActors];
                for (var a = 0; a < ldActors.length; a++) {
                    var nm = ldActors[a] && ldActors[a].name;
                    if (nm) out.actors.push({ name: String(nm).trim(), photo: '' });
                }
            }
        }

        // === 2. HTML fallback для title / poster / description ===
        if (!out.title) {
            var h1 = document.querySelector('h1');
            if (h1) out.title = (h1.textContent || '').trim().replace(/\\s+/g, ' ');
            if (!out.title && document.title) {
                out.title = document.title.split('|')[0].split('—')[0].trim();
            }
        }

        if (!out.poster) {
            var posterSelectors = [
                '.movie__poster img', '.film-poster img', '.main_poster img',
                '.poster img', '.sect-poster img', '[itemprop="image"]',
                '.pmovie__poster img', '.movie-poster img'
            ];
            for (var ps = 0; ps < posterSelectors.length; ps++) {
                var p = document.querySelector(posterSelectors[ps]);
                if (p) {
                    var url = norm(p.src || p.getAttribute('data-src') || p.getAttribute('data-original') || '');
                    if (url && url.indexOf('data:') !== 0) {
                        out.poster = url;
                        break;
                    }
                }
            }
        }
        if (!out.poster) {
            var all = document.querySelectorAll('img');
            for (var i = 0; i < all.length; i++) {
                var im = all[i];
                var w = im.naturalWidth || parseInt(im.getAttribute('width')) || 0;
                var h = im.naturalHeight || parseInt(im.getAttribute('height')) || 0;
                var src = norm(im.src || im.getAttribute('data-src') || '');
                if (src && w > 150 && h > 200) {
                    out.poster = src;
                    break;
                }
            }
        }

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

        // === 3. Плееры ===
        var PLAYER_HOSTS = ['cinemar', 'kodik', 'alloha', 'bazon', 'videocdn', 'sibnet', 'aniboom', 'hdvb', 'vadbam', 'pleer'];
        function isPlayerUrl(u) {
            if (!u) return false;
            var low = u.toLowerCase();
            for (var i = 0; i < PLAYER_HOSTS.length; i++) {
                if (low.indexOf(PLAYER_HOSTS[i]) !== -1) return true;
            }
            return false;
        }
        var iframes = document.querySelectorAll('iframe');
        var seen = {};
        for (var i = 0; i < iframes.length; i++) {
            var f = iframes[i];
            var src = norm(f.getAttribute('src') || '');
            if (!src) src = norm(f.getAttribute('data-src') || '');
            if (!src || seen[src]) continue;
            if (!isPlayerUrl(src)) continue;
            seen[src] = true;
            var name = (f.getAttribute('title') || '').trim() || ('Плеер ' + (out.players.length + 1));
            out.players.push({ name: name, url: src });
        }

        // === 4. Обогащаем актёров фотографиями из HTML, если у них ещё нет photo ===
        // Собираем карту: имя → url фото
        var photoByName = {};
        var containers = [
            '.persons__section', '.persons__list', '.persons-list',
            '.persons', '.actors', '[class*="persons"]', '[class*="actors"]'
        ];
        for (var ci = 0; ci < containers.length; ci++) {
            var sect = document.querySelector(containers[ci]);
            if (!sect) continue;
            var imgs = sect.querySelectorAll('img');
            for (var k = 0; k < imgs.length; k++) {
                var img = imgs[k];
                var photo = norm(img.src || img.getAttribute('data-src') || '');
                if (!photo || photo.indexOf('data:') === 0) continue;
                var nm = (img.alt || '').trim();
                if (!nm) {
                    var parent = img.closest('a') || img.parentElement;
                    var hops = 0;
                    while (parent && hops < 3 && !nm) {
                        var c = parent.cloneNode(true);
                        var cimg = c.querySelector('img');
                        if (cimg) cimg.remove();
                        var t = (c.textContent || '').trim().replace(/\\s+/g, ' ');
                        if (t && t.length < 80) nm = t;
                        parent = parent.parentElement;
                        hops++;
                    }
                }
                if (nm && !photoByName[nm]) photoByName[nm] = photo;
            }
        }

        // Подставляем фото к актёрам из JSON-LD
        for (var ai = 0; ai < out.actors.length; ai++) {
            if (out.actors[ai].photo) continue;
            var aName = out.actors[ai].name;
            if (photoByName[aName]) {
                out.actors[ai].photo = photoByName[aName];
            } else {
                // Поиск по частичному совпадению имени
                for (var key in photoByName) {
                    if (key.indexOf(aName) !== -1 || aName.indexOf(key) !== -1) {
                        out.actors[ai].photo = photoByName[key];
                        break;
                    }
                }
            }
        }

        // Если JSON-LD не дал актёров — берём их из HTML напрямую
        if (out.actors.length === 0) {
            for (var key2 in photoByName) {
                out.actors.push({ name: key2, photo: photoByName[key2] });
                if (out.actors.length >= 30) break;
            }
        }

        return JSON.stringify(out);
    })();
    """
}
