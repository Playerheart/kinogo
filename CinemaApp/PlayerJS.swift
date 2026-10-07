import Foundation

enum PlayerJS {
    static let hunter = """
    (function(){
    if (window.__hunterInstalled) return;
    window.__hunterInstalled = true;

    function reportVideo(u){
        if(!u) return;
        var l=String(u).toLowerCase();
        if(l.indexOf('.mp4')===-1&&l.indexOf('.m3u8')===-1&&l.indexOf('.mkv')===-1&&l.indexOf('.webm')===-1) return;
        try{window.webkit.messageHandlers.videoURL.postMessage(String(u));}catch(e){}
    }

    try{var _f=window.fetch;window.fetch=function(i){try{var u=(typeof i==='string')?i:(i&&i.url);if(u)reportVideo(u);}catch(e){}return _f.apply(this,arguments);};}catch(e){}
    try{var _o=XMLHttpRequest.prototype.open;XMLHttpRequest.prototype.open=function(m,u){try{if(u)reportVideo(u);}catch(e){}return _o.apply(this,arguments);};}catch(e){}
    try{var _c=HTMLAnchorElement.prototype.click;HTMLAnchorElement.prototype.click=function(){try{var h=this.href||'';if(h)reportVideo(h);}catch(e){}return _c.apply(this,arguments);};}catch(e){}
    try{
    if(!window.__hunterMediaHooked){
    window.__hunterMediaHooked=true;
    try{
    var _srcDesc=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,'src');
    if(_srcDesc&&_srcDesc.set){
    Object.defineProperty(HTMLMediaElement.prototype,'src',{
    set:function(v){try{reportVideo(v);}catch(e){}return _srcDesc.set.call(this,v);},
    get:_srcDesc.get,
    configurable:true
    });
    }
    }catch(e){}
    try{
    var _origSetAttribute=Element.prototype.setAttribute;
    Element.prototype.setAttribute=function(n,v){
    try{if((n==='src'||n==='data-src')&&v)reportVideo(v);}catch(e){}
    return _origSetAttribute.apply(this,arguments);
    };
    }catch(e){}
    }
    }catch(e){}

    // ---------------- UTIL ----------------
    function norm(t){ return String(t||'').replace(/\\s+/g,' ').replace(/^\\s+|\\s+$/g,''); }

    function classifyGroup(text){
        var t = String(text||'').toLowerCase();
        if (t.indexOf('сезон') !== -1 || t.indexOf('season') !== -1) return 'season';
        if (t.indexOf('серия') !== -1 || t.indexOf('серии') !== -1 ||
            t.indexOf('эпизод') !== -1 || t.indexOf('episode') !== -1) return 'episode';
        return 'voice';
    }

    // Возвращает { season:[...], episode:[...], voice:[...], active:{season:'',episode:'',voice:''} }
    function collectGroups(){
        var groups = {
            season: { items: [], active: '' },
            episode: { items: [], active: '' },
            voice:  { items: [], active: '' }
        };

        var titles = document.querySelectorAll('.playlist-title');
        for (var i = 0; i < titles.length; i++) {
            var title = titles[i];
            var titleText = norm(title.textContent);
            if (!titleText) continue;
            var kind = classifyGroup(titleText);

            // Ищем .playlist-dropdown рядом: сначала в родителе, потом siblings
            var dropdown = null;
            var parent = title.parentNode;
            if (parent) {
                dropdown = parent.querySelector('.playlist-dropdown');
            }
            if (!dropdown) {
                var sib = title.nextElementSibling;
                while (sib && !(sib.classList && sib.classList.contains('playlist-dropdown'))) {
                    sib = sib.nextElementSibling;
                }
                dropdown = sib;
            }

            var bucket = groups[kind];

            // Заголовок тоже может быть элементом (например, "Сезон 1")
            if (bucket.items.indexOf(titleText) === -1) {
                bucket.items.push(titleText);
            }

            if (!dropdown) continue;

            var btns = dropdown.querySelectorAll('button');
            for (var j = 0; j < btns.length; j++) {
                var b = btns[j];
                var cls = String(b.className || '');
                if (cls.indexOf('playlist-prev') !== -1) continue;
                if (cls.indexOf('playlist-next') !== -1) continue;

                var btext = norm(b.textContent);
                if (!btext) continue;
                if (bucket.items.indexOf(btext) === -1) {
                    bucket.items.push(btext);
                }
                if (cls.indexOf('is-active') !== -1 && !bucket.active) {
                    bucket.active = btext;
                }
            }
        }

        return groups;
    }

    // ---------------- ОТПРАВКА В SWIFT ----------------
    function reportAll(){
        var g = collectGroups();
        try {
            if (g.season.items.length)
                window.webkit.messageHandlers.seasonList.postMessage({
                    items: g.season.items,
                    active: g.season.active
                });
        } catch(e){}
        try {
            if (g.episode.items.length)
                window.webkit.messageHandlers.episodeList.postMessage({
                    items: g.episode.items,
                    active: g.episode.active
                });
        } catch(e){}
        try {
            if (g.voice.items.length)
                window.webkit.messageHandlers.voiceList.postMessage({
                    items: g.voice.items,
                    active: g.voice.active
                });
        } catch(e){}
    }

    // ---------------- КЛИК ----------------
    function selectInGroup(text, kind){
        var target = norm(text);
        if (!target) return false;

        // 1. Находим заголовок нужного типа
        var titles = document.querySelectorAll('.playlist-title');
        var titleEl = null;
        for (var i = 0; i < titles.length; i++) {
            if (classifyGroup(norm(titles[i].textContent)) === kind) {
                titleEl = titles[i];
                break;
            }
        }

        // 2. Открываем dropdown (клик по заголовку)
        if (titleEl) {
            try { titleEl.click(); } catch(e){}
        }

        // 3. Ищем кнопку с нужным текстом (в dropdown текущей группы)
        var doClick = function(){
            var dropdown = null;
            if (titleEl) {
                var parent = titleEl.parentNode;
                if (parent) dropdown = parent.querySelector('.playlist-dropdown');
                if (!dropdown) {
                    var sib = titleEl.nextElementSibling;
                    while (sib && !(sib.classList && sib.classList.contains('playlist-dropdown'))) {
                        sib = sib.nextElementSibling;
                    }
                    dropdown = sib;
                }
            }

            var scope = dropdown || document;
            var btns = scope.querySelectorAll('button');
            for (var j = 0; j < btns.length; j++) {
                var cls = String(btns[j].className || '');
                if (cls.indexOf('playlist-prev') !== -1) continue;
                if (cls.indexOf('playlist-next') !== -1) continue;
                if (norm(btns[j].textContent) === target) {
                    try { btns[j].click(); } catch(e){}
                    return true;
                }
            }

            // Фоллбек — глобальный поиск
            var all = document.querySelectorAll('button');
            for (var k = 0; k < all.length; k++) {
                var cls2 = String(all[k].className || '');
                if (cls2.indexOf('playlist-prev') !== -1) continue;
                if (cls2.indexOf('playlist-next') !== -1) continue;
                if (norm(all[k].textContent) === target) {
                    try { all[k].click(); } catch(e){}
                    return true;
                }
            }
            return false;
        };

        doClick();
        setTimeout(doClick, 250);
        setTimeout(doClick, 600);
        return true;
    }

    // ---------------- ДИАГНОСТИКА ----------------
    function collectDiag(){
        var out = { url: location.href, title: document.title, selects: [], buttons: [], options: [], dataAttrs: [], iframes: [] };

        var selects = document.querySelectorAll('select');
        for (var s = 0; s < selects.length && s < 20; s++) {
            var opts = selects[s].querySelectorAll('option');
            var arr = [];
            for (var o = 0; o < opts.length && o < 60; o++) {
                arr.push({
                    text: norm(opts[o].textContent).substring(0, 80),
                    value: String(opts[o].value || '').substring(0, 60),
                    selected: !!opts[o].selected
                });
            }
            out.selects.push({
                id: String(selects[s].id || ''),
                name: String(selects[s].name || ''),
                cls: String(selects[s].className || '').substring(0, 120),
                count: opts.length,
                options: arr
            });
        }

        var btns = document.querySelectorAll('button, [role=button]');
        for (var i = 0; i < btns.length && i < 120; i++) {
            out.buttons.push({
                text: norm(btns[i].textContent).substring(0, 60),
                id: String(btns[i].id || ''),
                cls: String(btns[i].className || '').substring(0, 120)
            });
        }

        var os = document.querySelectorAll('option');
        for (var i = 0; i < os.length && i < 100; i++) {
            out.options.push({
                text: norm(os[i].textContent).substring(0, 80),
                value: String(os[i].value || '').substring(0, 60),
                parentSelect: os[i].parentElement ? (os[i].parentElement.id || os[i].parentElement.name || '') : ''
            });
        }

        var da = document.querySelectorAll('[data-season],[data-episode],[data-src],[data-id],[data-translation],[data-voice]');
        for (var i = 0; i < da.length && i < 80; i++) {
            var attr = [];
            for (var a = 0; a < da[i].attributes.length; a++) {
                var an = da[i].attributes[a].name;
                if (an.indexOf('data-') === 0) attr.push(an + '=' + da[i].attributes[a].value);
            }
            out.dataAttrs.push({
                tag: da[i].tagName.toLowerCase(),
                text: norm(da[i].textContent).substring(0, 60),
                cls: String(da[i].className || '').substring(0, 120),
                attrs: attr.slice(0, 8)
            });
        }

        var ifr = document.querySelectorAll('iframe');
        for (var i = 0; i < ifr.length && i < 20; i++) {
            out.iframes.push({
                src: String(ifr[i].src || '').substring(0, 200),
                id: String(ifr[i].id || ''),
                cls: String(ifr[i].className || '').substring(0, 120)
            });
        }

        return out;
    }

    window.addEventListener('message', function(e){
        if (!e.data || !e.data.type) return;

        if (e.data.type === 'selectVoice') {
            selectInGroup(e.data.text, 'voice');
        }
        if (e.data.type === 'selectSeason') {
            selectInGroup(e.data.text, 'season');
            setTimeout(reportAll, 900);
            setTimeout(reportAll, 2000);
            setTimeout(reportAll, 4000);
        }
        if (e.data.type === 'selectEpisode') {
            selectInGroup(e.data.text, 'episode');
        }
        if (e.data.type === 'diagnose') {
            if (location.hostname.indexOf('cinemar') === -1) return;
            try {
                window.webkit.messageHandlers.cinemarDiag.postMessage(JSON.stringify(collectDiag()));
            } catch (err) {
                try { window.webkit.messageHandlers.cinemarDiag.postMessage('DIAG_ERROR: ' + String(err)); } catch(e){}
            }
        }
    });

    [1500, 3000, 5000, 8000, 12000, 18000].forEach(function(d){
        setTimeout(reportAll, d);
    });
    })();
    """
}
