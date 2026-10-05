import Foundation

enum ExtractionScripts {

    static let detail = """
    (function() {
        function norm(u) {
            if (!u) return '';
            u = u.trim();
            if (u.indexOf('//') === 0) return 'https:' + u;
            return u;
        }

        var out = { title: '', poster: '', description: '', players: [], actors: [] };

        // Title
        var h1 = document.querySelector('h1');
        if (h1) out.title = (h1.textContent || '').trim().replace(/\\s+/g, ' ');
        if (!out.title && document.title) {
            out.title = document.title.split('|')[0].split('—')[0].trim();
        }

        // Poster — расширенный набор селекторов
        var posterSelectors = [
            '.movie__poster img',
            '.film-poster img',
            '.main_poster img',
            '.poster img',
            '.sect-poster img',
            '[itemprop="image"]',
            '.movie-info img'
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

        // Description
        var at = document.querySelector('.article__text');
        if (at) {
            var clone = at.cloneNode(true);
            var info = clone.querySelector('.article__info');
            if (info) info.remove();
            var imp = clone.querySelector('.article__text-important');
            if (imp) imp.remove();
            out.description = (clone.textContent || '').trim().replace(/\\s+/g, ' ').substring(0, 3000);
        }

        // Players
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
            // Приоритет: src (актуальный), потом data-src
            var src = norm(f.getAttribute('src') || '');
            if (!src) src = norm(f.getAttribute('data-src') || '');
            if (!src || seen[src]) continue;
            if (!isPlayerUrl(src)) continue;
            seen[src] = true;
            var name = (f.getAttribute('title') || '').trim() || ('Плеер ' + (out.players.length + 1));
            out.players.push({ name: name, url: src });
        }

        // Actors — расширенный поиск
        var actorContainers = [
            '.persons__list',
            '.persons-list',
            '.persons',
            '.actors',
            '[class*="persons"]',
            '[class*="actors"]'
        ];
        var seenA = {};
        for (var ac = 0; ac < actorContainers.length; ac++) {
            var container = document.querySelector(actorContainers[ac]);
            if (!container) continue;
            var links = container.querySelectorAll('a');
            for (var j = 0; j < links.length; j++) {
                var a = links[j];
                var img = a.querySelector('img');
                if (!img) continue;
                var photo = norm(img.src || img.getAttribute('data-src') || '');
                if (!photo) continue;
                var name = (a.textContent || '').trim().replace(/\\s+/g, ' ');
                if (!name) name = (img.alt || '').trim();
                if (!name || name.length > 100 || seenA[name]) continue;
                seenA[name] = true;
                out.actors.push({ name: name, photo: photo });
            }
            if (out.actors.length > 0) break;
        }

        // Если ссылок не нашли — ищем одиночные карточки
        if (out.actors.length === 0) {
            var cards = document.querySelectorAll('.persons__item, .persons-item, [class*="person__"]');
            for (var k = 0; k < cards.length; k++) {
                var card = cards[k];
                var cimg = card.querySelector('img');
                if (!cimg) continue;
                var cphoto = norm(cimg.src || cimg.getAttribute('data-src') || '');
                if (!cphoto) continue;
                var cname = (card.textContent || '').trim().replace(/\\s+/g, ' ');
                if (!cname) cname = (cimg.alt || '').trim();
                if (!cname || cname.length > 100 || seenA[cname]) continue;
                seenA[cname] = true;
                out.actors.push({ name: cname, photo: cphoto });
            }
        }

        return JSON.stringify(out);
    })();
    """
}
