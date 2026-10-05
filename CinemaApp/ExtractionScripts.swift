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

        // Poster
        var p = document.querySelector('.poster img, [itemprop="image"], .movie__poster img, .film-poster img, .main_poster img');
        if (p) out.poster = norm(p.src || p.getAttribute('data-src') || '');

        // Description — берём .article__text, но удаляем вложенный .article__info
        var at = document.querySelector('.article__text');
        if (at) {
            var clone = at.cloneNode(true);
            var info = clone.querySelector('.article__info');
            if (info) info.remove();
            var imp = clone.querySelector('.article__text-important');
            if (imp) imp.remove();
            out.description = (clone.textContent || '').trim().replace(/\\s+/g, ' ').substring(0, 3000);
        }

        // Players — iframe с известных хостов
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
            var src = norm(f.src || f.getAttribute('data-src') || '');
            if (!src || seen[src]) continue;
            if (!isPlayerUrl(src)) continue;
            seen[src] = true;
            var name = (f.title || '').trim() || ('Плеер ' + (out.players.length + 1));
            out.players.push({ name: name, url: src });
        }

        // Actors
        var actorEls = document.querySelectorAll('.persons a, .persons__item, .persons-list a, [class*="person"] a');
        var seenA = {};
        for (var j = 0; j < actorEls.length; j++) {
            var a = actorEls[j];
            var img = a.querySelector('img');
            if (!img) continue;
            var photo = norm(img.src || img.getAttribute('data-src') || '');
            if (!photo) continue;
            var name = (a.textContent || '').trim().replace(/\\s+/g, ' ');
            if (!name) name = (img.alt || '').trim();
            if (!name || seenA[name]) continue;
            seenA[name] = true;
            out.actors.push({ name: name, photo: photo });
        }

        return JSON.stringify(out);
    })();
    """
}
