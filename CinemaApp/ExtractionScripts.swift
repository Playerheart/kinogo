import Foundation

enum ExtractionScripts {

    // MARK: - Каталог

    static func catalog(profile: SiteProfile) -> String {
        let yearFromTitle = profile.catalogYearFromTitle ? "true" : "false"
        return """
        (function() {
            var PROFILE = {
                card: '\(profile.catalogCard)',
                titleLink: '\(profile.catalogTitleLink)',
                posterImg: '\(profile.catalogPosterImg)',
                rating: '\(profile.catalogRating)',
                infoSpans: '\(profile.catalogInfoSpans)',
                yearFromTitle: \(yearFromTitle),
                maxCards: \(profile.catalogMaxCards)
            };

            function abs(u, baseHost) {
                if (!u) return '';
                u = String(u).trim();
                if (u.indexOf('//') === 0) return 'https:' + u;
                if (u.charAt(0) === '/') return 'https://' + baseHost + u;
                return u;
            }
            var BASE_HOST = location.hostname || '';

            try {
                var lazyImgs = document.querySelectorAll('img[data-src]');
                for (var li = 0; li < lazyImgs.length; li++) {
                    var limg = lazyImgs[li];
                    var ds = limg.getAttribute('data-src');
                    if (ds && (!limg.src || limg.src.indexOf('dot.gif') !== -1 || limg.src.indexOf('data:') === 0)) {
                        limg.src = ds;
                    }
                }
            } catch(e) {}

            var result = [];
            var seen = {};
            var cards = document.querySelectorAll(PROFILE.card);

            for (var i = 0; i < cards.length; i++) {
                var card = cards[i];
                var h2a = card.querySelector(PROFILE.titleLink);
                if (!h2a) continue;
                var href = h2a.getAttribute('href') || '';
                if (!href) continue;
                href = abs(href, BASE_HOST);
                if (seen[href]) continue;
                seen[href] = true;

                var title = (h2a.getAttribute('title') || h2a.textContent || '').trim();
                title = title.replace(/\\s+/g, ' ').trim();
                if (!title || title.length < 2 || title.length > 250) continue;

                var year = '';
                if (PROFILE.yearFromTitle) {
                    var ym = title.match(/\\((\\d{4})\\)\\s*$/);
                    if (ym) year = ym[1];
                }

                if (!year) {
                    var spans = card.querySelectorAll(PROFILE.infoSpans);
                    for (var si = 0; si < spans.length; si++) {
                        var b = spans[si].querySelector('b');
                        if (!b) continue;
                        var bt = (b.textContent || '').toLowerCase();
                        if (bt.indexOf('год') !== -1 || bt.indexOf('вышел') !== -1) {
                            var txt = (spans[si].textContent || '').replace(b.textContent, '').trim();
                            var ym2 = txt.match(/\\b(19|20)\\d{2}\\b/);
                            if (ym2) { year = ym2[0]; break; }
                        }
                    }
                }

                var img = card.querySelector(PROFILE.posterImg);
                var poster = '';
                if (img) {
                    var dsrc = img.getAttribute('data-src') || '';
                    var ssrc = img.getAttribute('src') || '';
                    if (dsrc && dsrc.indexOf('dot.gif') === -1) poster = dsrc;
                    else if (ssrc && ssrc.indexOf('dot.gif') === -1) poster = ssrc;
                    poster = abs(poster, BASE_HOST);
                }

                var rating = '';
                var rs = card.querySelector(PROFILE.rating);
                if (rs) {
                    var rm = (rs.textContent || '').match(/(\\d+\\.\\d+)/);
                    if (rm) rating = rm[1];
                }

                result.push({
                    title: title,
                    url: href,
                    poster: poster,
                    year: year,
                    rating: rating
                });

                if (result.length >= PROFILE.maxCards) break;
            }
            return JSON.stringify(result);
        })();
        """
    }

    // MARK: - Детальная страница

    static func detail(profile: SiteProfile) -> String {
        let hostsJS = profile.playerHosts.map { "\"\($0)\"" }.joined(separator: ",")
        return """
        (function() {
            var PROFILE = {
                h1: '\(profile.detailH1)',
                posterImg: '\(profile.detailPosterImg)',
                infoSpans: '\(profile.detailInfoSpans)',
                fDop: '\(profile.detailFDop)',
                description: '\(profile.detailDescription)',
                actorsContainer: '\(profile.detailActorsContainer)',
                playersTabs: '\(profile.detailPlayersTabs)',
                playersContainer: '\(profile.detailPlayersContainer)',
                related: '\(profile.detailRelated)',
                playerHosts: [\(hostsJS)]
            };

            var BASE_HOST = location.hostname || '';
            function norm(u) {
                if (!u) return '';
                u = String(u).trim();
                if (u.indexOf('//') === 0) return 'https:' + u;
                if (u.charAt(0) === '/') return 'https://' + BASE_HOST + u;
                return u;
            }

            var out = {
                title: '', poster: '', description: '',
                year: '', country: '', duration: '', genres: '',
                quality: '', voices: '',
                season: '', lastEpisode: '',
                players: [], actors: [], related: []
            };

            // ---- JSON-LD ----
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

            var ldActors = [];
            if (ld) {
                if (ld.name) out.title = String(ld.name).trim();
                if (ld.description) out.description = String(ld.description).trim().substring(0, 3000);
                if (ld.dateCreated) {
                    var ym = String(ld.dateCreated).match(/\\b(19|20)\\d{2}\\b/);
                    if (ym) out.year = ym[0];
                }
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
                    var gs = [];
                    for (var gi = 0; gi < g.length; gi++) {
                        var gv = String(g[gi]).trim();
                        if (gv) gs.push(gv.charAt(0).toUpperCase() + gv.slice(1));
                    }
                    out.genres = gs.join(' / ');
                }
                if (ld.image) {
                    try {
                        var im = ld.image;
                        if (typeof im === 'string') out.poster = im;
                        else if (im && im.url) out.poster = String(im.url);
                    } catch(e) {}
                }
                if (ld.actor) {
                    var actors = ld.actor;
                    if (!Array.isArray(actors)) actors = [actors];
                    for (var ai2 = 0; ai2 < actors.length; ai2++) {
                        if (actors[ai2] && actors[ai2].name) {
                            ldActors.push(String(actors[ai2].name).trim());
                        }
                    }
                }
            }

            // ---- H1 title ----
            var h1 = document.querySelector(PROFILE.h1);
            if (h1) {
                var t = (h1.textContent || '').trim().replace(/\\s+/g, ' ');
                if (t) out.title = t;
            }

            // ---- Poster ----
            if (!out.poster) {
                var posterImg = document.querySelector(PROFILE.posterImg);
                if (posterImg) {
                    var psrc = posterImg.getAttribute('src') || posterImg.getAttribute('data-src') || '';
                    if (psrc && psrc.indexOf('dot.gif') === -1 && psrc.indexOf('noposter') === -1) {
                        out.poster = norm(psrc);
                    }
                }
            } else {
                out.poster = norm(out.poster);
            }

            // ---- infoSpans: метки поддерживают и старые, и новые названия ----
            function findSpanValue(labels) {
                var spans = document.querySelectorAll(PROFILE.infoSpans);
                for (var i = 0; i < spans.length; i++) {
                    var b = spans[i].querySelector('b');
                    if (!b) continue;
                    var bText = (b.textContent || '').replace(/:\\s*$/, '').trim().toLowerCase();
                    for (var li = 0; li < labels.length; li++) {
                        if (bText === labels[li].toLowerCase()) {
                            return (spans[i].textContent || '').replace(b.textContent, '').trim();
                        }
                    }
                }
                return '';
            }

            var vYear = findSpanValue(['Год выпуска', 'Вышел в', 'Год']);
            if (vYear && !out.year) {
                var ym2 = vYear.match(/\\b(19|20)\\d{2}\\b/);
                if (ym2) out.year = ym2[0];
            }
            var vCountry = findSpanValue(['Страна', 'Сняли в', 'Страны']);
            if (vCountry) out.country = vCountry;

            // Genres
            var genreSpan = null;
            var sSpans = document.querySelectorAll(PROFILE.infoSpans);
            var genreLabels = ['жанр', 'жанры'];
            for (var i = 0; i < sSpans.length; i++) {
                var b = sSpans[i].querySelector('b');
                if (!b) continue;
                var bt = (b.textContent || '').replace(/:\\s*$/, '').trim().toLowerCase();
                if (genreLabels.indexOf(bt) !== -1) { genreSpan = sSpans[i]; break; }
            }
            if (genreSpan) {
                var gaLinks = genreSpan.querySelectorAll('a');
                var gs2 = [];
                for (var i = 0; i < gaLinks.length; i++) {
                    var gv = (gaLinks[i].textContent || '').trim();
                    if (gv) gs2.push(gv);
                }
                if (gs2.length) out.genres = gs2.join(' / ');
            }

            // ---- fDop ----
            function fieldFromFDop(labels) {
                var divs = document.querySelectorAll(PROFILE.fDop);
                for (var i = 0; i < divs.length; i++) {
                    var b = divs[i].querySelector('b');
                    if (!b) continue;
                    var bt = (b.textContent || '').replace(/:\\s*$/, '').trim().toLowerCase();
                    for (var li = 0; li < labels.length; li++) {
                        if (bt === labels[li].toLowerCase()) {
                            return (divs[i].textContent || '').replace(b.textContent, '').trim();
                        }
                    }
                }
                return '';
            }
            var q = fieldFromFDop(['Качество']);
            if (q) out.quality = q;
            var d = fieldFromFDop(['Длительность', 'Время']);
            if (d) out.duration = d;
            var v = fieldFromFDop(['Перевод', 'Озвучка']);
            if (v) out.voices = v;
            var s = fieldFromFDop(['Сезон']);
            if (s) out.season = s;
            var le = fieldFromFDop(['Последняя серия онлайн', 'Последняя серия']);
            if (le) out.lastEpisode = le;

            // ---- Description ----
            if (!out.description) {
                var dP = document.querySelector(PROFILE.description);
                if (dP) {
                    out.description = (dP.textContent || '').trim().replace(/\\s+/g, ' ').substring(0, 3000);
                }
            }

            // ---- Actors ----
            var seenA = {};
            var castSpans = document.querySelectorAll(PROFILE.actorsContainer);
            for (var ci = 0; ci < castSpans.length; ci++) {
                var aEl = castSpans[ci];
                var name = (aEl.getAttribute('title') || aEl.textContent || '').trim();
                name = name.replace(/\\s+/g, ' ');
                if (!name || seenA[name]) continue;

                // Пытаемся вытащить фото из background-image в дочернем элементе
                var photo = '';
                try {
                    var fotoEl = aEl.querySelector('.persons__foto, [class*="photo"], [class*="foto"]');
                    if (fotoEl) {
                        var style = fotoEl.getAttribute('style') || '';
                        var m = style.match(/url\\(['"]?([^'"\\)]+)['"]?\\)/);
                        if (m && m[1]) photo = norm(m[1]);
                    }
                    if (!photo) {
                        var imgInA = aEl.querySelector('img');
                        if (imgInA) {
                            var ii = imgInA.getAttribute('src') || imgInA.getAttribute('data-src') || '';
                            if (ii && ii.indexOf('dot.gif') === -1) photo = norm(ii);
                        }
                    }
                } catch(e) {}

                seenA[name] = true;
                out.actors.push({
                    name: name,
                    photo: photo,
                    url: norm(aEl.getAttribute('href') || '')
                });
            }

            // Fallback: JSON-LD actor[] — если в HTML актёры не нашлись
            if (out.actors.length === 0 && ldActors.length > 0) {
                for (var ldi = 0; ldi < ldActors.length; ldi++) {
                    var nm = ldActors[ldi];
                    if (!nm || seenA[nm]) continue;
                    seenA[nm] = true;
                    out.actors.push({ name: nm, photo: '', url: '' });
                }
            }

            // ---- Players ----
            var seenP = {};
            function isPlayerUrl(u) {
                if (!u) return false;
                var low = u.toLowerCase();
                for (var i = 0; i < PROFILE.playerHosts.length; i++) {
                    if (low.indexOf(PROFILE.playerHosts[i]) !== -1) return true;
                }
                return false;
            }

            var tabs = document.querySelectorAll(PROFILE.playersTabs);
            for (var t2 = 0; t2 < tabs.length; t2++) {
                var src = norm(tabs[t2].getAttribute('data-src') || '');
                if (!src || !isPlayerUrl(src) || seenP[src]) continue;
                seenP[src] = true;
                var tabName = (tabs[t2].textContent || '').trim() || ('Плеер ' + (out.players.length + 1));
                out.players.push({name: tabName, url: src});
            }

            var iframes = document.querySelectorAll(PROFILE.playersContainer);
            for (var i = 0; i < iframes.length; i++) {
                var src2 = norm(iframes[i].getAttribute('src') || '');
                if (!src2 || !isPlayerUrl(src2) || seenP[src2]) continue;
                seenP[src2] = true;
                out.players.push({name: 'Плеер ' + (out.players.length + 1), url: src2});
            }

            // ---- Recommendations ----
            var seenR = {};
            var relItems = document.querySelectorAll(PROFILE.related);
            for (var ri = 0; ri < relItems.length; ri++) {
                var rel = relItems[ri];
                var rHref = norm(rel.getAttribute('href') || '');
                if (!rHref || seenR[rHref]) continue;
                seenR[rHref] = true;

                var rImg = rel.querySelector('img');
                var rPoster = '';
                if (rImg) {
                    var rsrc = rImg.getAttribute('data-src') || rImg.getAttribute('src') || '';
                    if (rsrc && rsrc.indexOf('dot.gif') === -1) rPoster = norm(rsrc);
                }
                // Название: сначала атрибут title, потом текст, минус картинки
                var rTitle = (rel.getAttribute('title') || '').trim();
                if (!rTitle) {
                    rTitle = (rel.textContent || '').trim().replace(/\\s+/g, ' ');
                }
                if (!rTitle) continue;

                var rYear = '';
                var rym = rTitle.match(/\\((\\d{4})\\)/);
                if (rym) rYear = rym[1];

                out.related.push({
                    title: rTitle,
                    url: rHref,
                    poster: rPoster,
                    year: rYear,
                    rating: ''
                });
                if (out.related.length >= 20) break;
            }

            return JSON.stringify(out);
        })();
        """
    }
}
