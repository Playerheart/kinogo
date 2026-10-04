import Foundation

enum ExtractionScripts {

    /// Сбор каталога с главной страницы
    static let catalog = """
    (function() {
        var result = [];
        var seen = {};
        var anchors = document.querySelectorAll('a[href]');
        for (var i = 0; i < anchors.length; i++) {
            var a = anchors[i];
            var href = a.href || '';
            if (!href || seen[href]) continue;
            // Только ссылки на фильмы/сериалы
            if (!href.match(/\\/(film|films|movie|series|serial|mult|cartoon|dorama|anime)\\//i)) continue;
            var img = a.querySelector('img');
            if (!img) continue;
            var imgSrc = img.src || img.getAttribute('data-src') || img.getAttribute('data-original') || '';
            if (!imgSrc || imgSrc.indexOf('data:') === 0) continue;

            var title = '';
            var titleEl = a.querySelector('[class*="title" i], [class*="name" i], h1, h2, h3, h4');
            if (titleEl) title = (titleEl.textContent || '').trim();
            if (!title) title = (img.alt || '').trim();
            if (!title) title = (a.textContent || '').trim();
            title = title.replace(/\\s+/g, ' ').trim();
            if (!title || title.length > 250) continue;

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
            if (result.length >= 100) break;
        }
        return JSON.stringify(result);
    })();
    """

    /// Детали одного фильма: название, описание, постер, плееры, загрузки
    static let detail = """
    (function() {
        var out = { title: '', description: '', poster: '', players: [], downloads: [] };
        var seen = {};

        var t = document.querySelector('h1, [itemprop="name"], .movie__title, .film-title, .page__title');
        if (t) out.title = (t.textContent || '').trim().replace(/\\s+/g, ' ');

        var d = document.querySelector('[itemprop="description"], .movie__description, .film-description, .full-story, .description');
        if (d) out.description = (d.textContent || '').trim().substring(0, 3000);

        var p = document.querySelector('[itemprop="image"], .movie__poster img, .film-poster img, .poster img');
        if (p) out.poster = p.src || p.getAttribute('data-src') || '';

        // Плееры: ищем iframe с известных видеохостингов + опции озвучки (data-src)
        var iframes = document.querySelectorAll('iframe[src], iframe[data-src]');
        for (var i = 0; i < iframes.length; i++) {
            var src = iframes[i].src || iframes[i].getAttribute('data-src') || '';
            if (!src || seen[src]) continue;
            if (src.match(/(ads|banner|b5c1d2e8c9982e3b965a27ac72ru7284cc|pinco|kysh|google|doubleclick|bet|casino)/i)) continue;
            seen[src] = true;
            var name = 'Плеер ' + (out.players.length + 1);
            var wrap = iframes[i].closest('[data-title], [data-name], .tabs__content, li, .player-tab');
            if (wrap) {
                var lbl = wrap.querySelector('[class*="title" i], [class*="name" i], [class*="label" i]');
                if (lbl) name = (lbl.textContent || '').trim().substring(0, 60) || name;
            }
            out.players.push({ name: name, url: src });
        }

        // Кнопки озвучки / серии: у них обычно data-src или href с плеером
        var voiceNodes = document.querySelectorAll('[data-translation], [data-voice], [data-player], [data-src]');
        for (var j = 0; j < voiceNodes.length; j++) {
            var el = voiceNodes[j];
            var u = el.getAttribute('data-src') || el.getAttribute('data-url') || el.getAttribute('data-player') || '';
            if (!u || seen[u]) continue;
            if (u.match(/(ads|banner|pinco|kysh|google|doubleclick|bet|casino)/i)) continue;
            if (!u.match(/^https?:\\/\\//)) continue;
            seen[u] = true;
            var nm = (el.textContent || '').trim().substring(0, 60) || ('Источник ' + (out.players.length + 1));
            out.players.push({ name: nm, url: u });
        }

        // Скачивание
        var dl = document.querySelectorAll('a[href*="/download"], a[href$=".mp4"], a[href$=".mkv"], a[href$=".avi"], a[download], a[href*="dl="]');
        for (var k = 0; k < dl.length; k++) {
            var href = dl[k].href || '';
            if (!href || seen[href]) continue;
            if (href.match(/(ads|banner|pinco|kysh|google|doubleclick)/i)) continue;
            seen[href] = true;
            var q = (dl[k].textContent || '').trim().replace(/\\s+/g, ' ').substring(0, 60) || 'Скачать';
            out.downloads.push({ quality: q, url: href });
        }

        return JSON.stringify(out);
    })();
    """
}
