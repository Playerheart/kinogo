import Foundation

enum ExtractionScripts {

    /// Сбор каталога: работает максимально мягко, ищет любые ссылки с постерами.
    static let catalog = """
    (function() {
        // Принудительно вытаскиваем ленивые картинки
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

        var skipWords = ['войти', 'регистрация', 'все', 'далее', 'назад', 'следующая',
                         'предыдущая', 'наверх', 'комментар', 'подписаться', 'смотреть онлайн',
                         'оставить', 'перейти', 'главная', 'контакты', 'поиск', 'меню'];

        for (var i = 0; i < anchors.length; i++) {
            var a = anchors[i];
            var href = a.href || '';
            if (!href) continue;
            if (href.indexOf('javascript:') === 0) continue;
            if (href.indexOf('mailto:') === 0) continue;
            if (href.indexOf('tel:') === 0) continue;
            if (href.indexOf('#') === 0) continue;

            // Должна быть ссылка с расширением .html или числовым id + slug
            var isFilmLink = /\\.html($|[?#])/.test(href) ||
                             /\\/\\d+-[\\w-]+/.test(href) ||
                             /\\/(film|films|movie|series|serial|mult|cartoon|dorama|anime|online)/i.test(href);
            if (!isFilmLink) continue;
            if (seen[href]) continue;

            var img = a.querySelector('img');
            if (!img) continue;

            var imgSrc = img.src || img.getAttribute('data-src') || img.getAttribute('data-original') || img.getAttribute('data-lazy') || '';
            if (!imgSrc || imgSrc.indexOf('data:') === 0) continue;

            // Пропускаем мелкие картинки (иконки/логотипы)
            var w = img.naturalWidth || parseInt(img.getAttribute('width')) || 0;
            var h = img.naturalHeight || parseInt(img.getAttribute('height')) || 0;
            if (w > 0 && w < 80) continue;
            if (h > 0 && h < 80) continue;

            // Заголовок: alt картинки → элемент с title/name → текст ссылки
            var title = (img.alt || '').trim();
            if (!title) {
                var titleEl = a.querySelector('[class*="title" i], [class*="name" i], [class*="caption" i]');
                if (titleEl) title = (titleEl.textContent || '').trim();
            }
            if (!title) title = (a.textContent || '').trim();
            title = title.replace(/\\s+/g, ' ').trim();

            // Отсев мусорных заголовков
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

    /// Детали фильма: название, описание, постер, плееры, скачивание.
    static let detail = """
    (function() {
        var out = { title: '', description: '', poster: '', players: [], downloads: [] };
        var seen = {};

        // Название
        var t = document.querySelector('h1, [itemprop="name"], .movie__title, .film-title, .page__title, .title');
        if (t) out.title = (t.textContent || '').trim().replace(/\\s+/g, ' ');

        // Описание
        var d = document.querySelector('[itemprop="description"], .movie__description, .film-description, .full-story, .description, .short-story');
        if (d) out.description = (d.textContent || '').trim().substring(0, 3000);

        // Постер
        var p = document.querySelector('[itemprop="image"], .movie__poster img, .film-poster img, .poster img, .main_poster img');
        if (p) {
            out.poster = p.src || p.getAttribute('data-src') || '';
        }

        var adPatterns = /(ads|banner|b5c1d2e8c9982e3b965a27ac72ru7284cc|pinco|kysh|google|doubleclick|bet|casino)/i;

        // Плееры: iframe с видео-хостингов
        var iframes = document.querySelectorAll('iframe[src], iframe[data-src]');
        for (var i = 0; i < iframes.length; i++) {
            var src = iframes[i].src || iframes[i].getAttribute('data-src') || '';
            if (!src || seen[src]) continue;
            if (adPatterns.test(src)) continue;
            seen[src] = true;
            var name = 'Плеер ' + (out.players.length + 1);
            var wrap = iframes[i].closest('[data-title], [data-name], .tabs__content, li, .player-tab, .tab-pane');
            if (wrap) {
                var lbl = wrap.querySelector('[class*="title" i], [class*="name" i], [class*="label" i]');
                if (lbl) {
                    var n = (lbl.textContent || '').trim().substring(0, 60);
                    if (n) name = n;
                }
            }
            out.players.push({ name: name, url: src });
        }

        // Озвучки / альтернативные источники — data-src, data-url, data-player
        var voiceNodes = document.querySelectorAll('[data-translation], [data-voice], [data-player], [data-src], [data-url], a[href*="/player"], a[href*="/play"]');
        for (var j = 0; j < voiceNodes.length; j++) {
            var el = voiceNodes[j];
            var u = el.getAttribute('data-src') || el.getAttribute('data-url') || el.getAttribute('data-player') || '';
            if (!u || seen[u]) continue;
            if (adPatterns.test(u)) continue;
            if (u.indexOf('//') === -1) continue;
            seen[u] = true;
            var nm = (el.textContent || '').trim().replace(/\\s+/g, ' ').substring(0, 60);
            if (!nm) nm = 'Источник ' + (out.players.length + 1);
            out.players.push({ name: nm, url: u });
        }

        // Скачивание
        var dl = document.querySelectorAll('a[href*="/download"], a[href$=".mp4"], a[href$=".mkv"], a[href$=".avi"], a[download], a[href*="dl="]');
        for (var k = 0; k < dl.length; k++) {
            var href = dl[k].href || '';
            if (!href || seen[href]) continue;
            if (adPatterns.test(href)) continue;
            seen[href] = true;
            var q = (dl[k].textContent || '').trim().replace(/\\s+/g, ' ').substring(0, 60);
            if (!q) q = 'Скачать';
            out.downloads.push({ quality: q, url: href });
        }

        return JSON.stringify(out);
    })();
    """
}
