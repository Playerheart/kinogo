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
        var posterSelectors = [
            '.movie__poster img', '.film-poster img', '.main_poster img',
            '.poster img', '.sect-poster img', '[itemprop="image"]'
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
            var src = norm(f.getAttribute('src') || '');
            if (!src) src = norm(f.getAttribute('data-src') || '');
            if (!src || seen[src]) continue;
            if (!isPlayerUrl(src)) continue;
            seen[src] = true;
            var name = (f.getAttribute('title') || '').trim() || ('Плеер ' + (out.players.length + 1));
            out.players.push({ name: name, url: src });
        }

        // Actors — ищем ВСЕ img внутри .persons__section, имя из alt или ближайшего родителя
        var section = document.querySelector('.persons__section, .persons, .persons__list, .actors, [class*="persons"], [class*="actors"]');
        var seenA = {};
        if (section) {
            var imgs = section.querySelectorAll('img');
            for (var k = 0; k < imgs.length; k++) {
                var img = imgs[k];
                var photo = norm(img.src || img.getAttribute('data-src') || '');
                if (!photo || photo.indexOf('data:') === 0) continue;
                if (img.complete && img.naturalWidth === 0) continue;

                var name = (img.alt || '').trim();
                if (!name) {
                    var parent = img.closest('a') || img.parentElement;
                    if (parent) {
                        var clone = parent.cloneNode(true);
                        var cimg = clone.querySelector('img');
                        if (cimg) cimg.remove();
                        name = (clone.textContent || '').trim().replace(/\\s+/g, ' ');
                    }
                }
                if (!name || name.length > 100 || seenA[name]) continue;
                seenA[name] = true;
                out.actors.push({ name: name, photo: photo });
            }
        }

        return JSON.stringify(out);
    })();
    """
}
