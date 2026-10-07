import Foundation

enum PlayerJS {
    static let hunter = """
    (function(){
    if (window.__hunterInstalled) return;
    window.__hunterInstalled = true;

    // ---------------- VIDEO URL HUNTER ----------------
    var __seenVideo = {};
    function reportVideo(u, force){
        if(!u) return;
        var s = String(u);
        if(!s) return;
        var l = s.toLowerCase();
        if(l.indexOf('blob:')===0 || l.indexOf('data:')===0) return;
        if(__seenVideo[s]) return;

        var hasVideoExt = l.indexOf('.mp4')!==-1 || l.indexOf('.m3u8')!==-1 ||
                          l.indexOf('.mkv')!==-1 || l.indexOf('.webm')!==-1 ||
                          l.indexOf('.mov')!==-1 || l.indexOf('.m4v')!==-1;
        var isCinemap = l.indexOf('cinemap.cc')!==-1 || l.indexOf('cinemap.')!==-1;
        if(!hasVideoExt && !(force && isCinemap)) return;

        __seenVideo[s] = 1;
        try{window.webkit.messageHandlers.videoURL.postMessage(s);}catch(e){}
    }

    function scanExistingVideos(){
        try{
            var vids = document.querySelectorAll('video, audio, source');
            for(var i=0;i<vids.length;i++){
                var el = vids[i];
                var s = el.currentSrc || el.src || el.getAttribute('src') || '';
                if(s) reportVideo(s);
            }
        }catch(e){}
    }

    function installMediaObserver(){
        try{
            if(window.__hunterMediaObserver) return;
            window.__hunterMediaObserver = 1;
            var obs = new MutationObserver(function(muts){
                for(var i=0;i<muts.length;i++){
                    var m = muts[i];
                    if(m.type==='childList'){
                        for(var j=0;j<m.addedNodes.length;j++){
                            var n = m.addedNodes[j];
                            if(!n || n.nodeType!==1) continue;
                            try{
                                if(n.tagName==='VIDEO' || n.tagName==='AUDIO' || n.tagName==='SOURCE'){
                                    var s = n.src || n.getAttribute('src') || '';
                                    if(s) reportVideo(s);
                                }
                                var inner = n.querySelectorAll ? n.querySelectorAll('video, audio, source') : [];
                                for(var k=0;k<inner.length;k++){
                                    var s2 = inner[k].src || inner[k].getAttribute('src') || '';
                                    if(s2) reportVideo(s2);
                                }
                            }catch(e){}
                        }
                    } else if(m.type==='attributes'){
                        try{
                            var t = m.target;
                            if(t && (t.tagName==='VIDEO' || t.tagName==='SOURCE' || t.tagName==='AUDIO')){
                                var s3 = t.src || t.getAttribute('src') || '';
                                if(s3) reportVideo(s3);
                            }
                        }catch(e){}
                    }
                }
            });
            var root = document.documentElement || document;
            obs.observe(root, {childList:true, subtree:true, attributes:true, attributeFilter:['src']});
        }catch(e){}
    }

    function autoStartPlayback(){
        try{
            var vids = document.querySelectorAll('video');
            for(var i=0;i<vids.length;i++){
                try{ var p = vids[i].play(); if(p && p.catch) p.catch(function(){}); }catch(e){}
            }
        }catch(e){}
        try{
            var btns = document.querySelectorAll(
                '.vjs-big-play-button, .play-button, .player-poster, ' +
                '[class*="play-btn"], [class*="playButton"], [class*="play_button"], ' +
                '.poster-overlay, [class*="poster-play"]'
            );
            for(var i=0;i<btns.length;i++){
                try{ btns[i].click(); }catch(e){}
            }
        }catch(e){}
    }

    try{
        var _f=window.fetch;
        window.fetch=function(i, init){
            var url = (typeof i==='string')?i:(i&&i.url);
            try{ if(url) reportVideo(url); }catch(e){}
            var p = _f.apply(this, arguments);
            try{
                if(p && p.then){
                    p.then(function(resp){
                        try{
                            var ct = '';
                            try{ ct = (resp.headers && resp.headers.get('content-type')) || ''; }catch(e){}
                            var lower = ct.toLowerCase();
                            if(lower.indexOf('video/')!==-1 ||
                               lower.indexOf('mpegurl')!==-1 ||
                               lower.indexOf('mpeg-url')!==-1){
                                reportVideo(resp.url || url, true);
                            }
                        }catch(e){}
                        return resp;
                    }, function(){});
                }
            }catch(e){}
            return p;
        };
    }catch(e){}

    try{
        var _o=XMLHttpRequest.prototype.open;
        var _s=XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.open=function(m,u){
            try{ this.__hunter_url = u; if(u) reportVideo(u); }catch(e){}
            return _o.apply(this, arguments);
        };
        XMLHttpRequest.prototype.send=function(){
            try{
                var self = this;
                this.addEventListener('load', function(){
                    try{
                        var ct = '';
                        try{ ct = self.getResponseHeader('content-type') || ''; }catch(e){}
                        var lower = ct.toLowerCase();
                        if(lower.indexOf('video/')!==-1 ||
                           lower.indexOf('mpegurl')!==-1 ||
                           lower.indexOf('mpeg-url')!==-1){
                            reportVideo(self.__hunter_url, true);
                        }
                    }catch(e){}
                });
            }catch(e){}
            return _s.apply(this, arguments);
        };
    }catch(e){}

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
    var _srcDesc2=Object.getOwnPropertyDescriptor(HTMLSourceElement.prototype,'src');
    if(_srcDesc2&&_srcDesc2.set){
    Object.defineProperty(HTMLSourceElement.prototype,'src',{
    set:function(v){try{reportVideo(v);}catch(e){}return _srcDesc2.set.call(this,v);},
    get:_srcDesc2.get,
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

    scanExistingVideos();
    installMediaObserver();

    // ---------------- UTIL ----------------
    function norm(t){ return String(t||'').replace(/\\s+/g,' ').replace(/^\\s+|\\s+$/g,''); }

    function classifyGroup(text){
        var t = String(text||'').toLowerCase();
        if (t.indexOf('сезон') !== -1 || t.indexOf('season') !== -1) return 'season';
        if (t.indexOf('серия') !== -1 || t.indexOf('серии') !== -1 ||
            t.indexOf('эпизод') !== -1 || t.indexOf('episode') !== -1) return 'episode';
        return 'voice';
    }

    function addUnique(arr, val){
        if(!val) return;
        if(arr.indexOf(val) !== -1) return;
        arr.push(val);
    }

    function findDropdownForTitle(title){
        var parent = title.parentNode;
        if(parent){
            var d = parent.querySelector('.playlist-dropdown');
            if(d) return d;
        }
        var sib = title.nextElementSibling;
        while(sib){
            if(sib.classList && sib.classList.contains('playlist-dropdown')) return sib;
            sib = sib.nextElementSibling;
        }
        return null;
    }

    function isNavButton(b){
        var cls = String((b && b.className) || '');
        return cls.indexOf('playlist-prev')!==-1 || cls.indexOf('playlist-next')!==-1;
    }

    function collectButtonsFrom(container, bucket){
        var btns = container.querySelectorAll('button, a');
        for(var j=0;j<btns.length;j++){
            var b = btns[j];
            if(isNavButton(b)) continue;
            var btext = norm(b.textContent);
            if(!btext) continue;
            if(btext.length > 120) continue;
            addUnique(bucket.items, btext);
            var cls = String(b.className || '');
            if((cls.indexOf('is-active')!==-1 || cls.indexOf('active')!==-1) && !bucket.active){
                bucket.active = btext;
            }
        }
    }

    function collectGroups(){
        var groups = {
            season: { items: [], active: '' },
            episode: { items: [], active: '' },
            voice:  { items: [], active: '' }
        };

        // Primary: .playlist-title + .playlist-dropdown
        var titles = document.querySelectorAll('.playlist-title');
        for (var i = 0; i < titles.length; i++) {
            var title = titles[i];
            var titleText = norm(title.textContent);
            if (!titleText) continue;
            var kind = classifyGroup(titleText);
            var dropdown = findDropdownForTitle(title);
            var bucket = groups[kind];
            addUnique(bucket.items, titleText);
            if (!dropdown) continue;
            collectButtonsFrom(dropdown, bucket);
        }

        // Fallback для озвучки (у cinemar бывает отдельный ряд табов)
        if (groups.voice.items.length <= 1) {
            var voiceSelectors = [
                '.translations a', '.translations button',
                '.translation-list a', '.translation-list button',
                '.voice-list a', '.voice-list button',
                '.voices a', '.voices button',
                '.player-translations a', '.player-translations button',
                '[data-translation]', '[data-voice]'
            ];
            for (var vs = 0; vs < voiceSelectors.length; vs++) {
                var els = document.querySelectorAll(voiceSelectors[vs]);
                for (var ei = 0; ei < els.length; ei++) {
                    var el = els[ei];
                    var txt = norm(el.textContent);
                    if (!txt || txt.length > 120) continue;
                    addUnique(groups.voice.items, txt);
                    var cls2 = String(el.className || '');
                    if((cls2.indexOf('is-active')!==-1 || cls2.indexOf('active')!==-1) && !groups.voice.active){
                        groups.voice.active = txt;
                    }
                }
            }
        }

        return groups;
    }

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

    // ---------------- CLICK ----------------
    function selectInGroup(text, kind){
        var target = norm(text);
        if (!target) return false;

        function tryClick(){
            var titles = document.querySelectorAll('.playlist-title');
            var titleEl = null;
            for (var i = 0; i < titles.length; i++) {
                if (classifyGroup(norm(titles[i].textContent)) === kind) {
                    titleEl = titles[i];
                    break;
                }
            }
            if (titleEl) {
                try { titleEl.click(); } catch(e){}
                var dropdown = findDropdownForTitle(titleEl);
                var scope = dropdown || document;
                var btns = scope.querySelectorAll('button, a');
                for (var j = 0; j < btns.length; j++) {
                    var b = btns[j];
                    if (isNavButton(b)) continue;
                    if (norm(b.textContent) === target) {
                        try { b.click(); } catch(e){}
                        return true;
                    }
                }
            }
            var all = document.querySelectorAll('button, a, [role=button]');
            for (var k = 0; k < all.length; k++) {
                var el = all[k];
                if (isNavButton(el)) continue;
                if (norm(el.textContent) === target) {
                    try { el.click(); } catch(e){}
                    return true;
                }
            }
            return false;
        }

        tryClick();
        setTimeout(tryClick, 250);
        setTimeout(tryClick, 700);
        return true;
    }

    // ---------------- ДИАГНОСТИКА ----------------
    function collectDiag(){
        var out = {
            url: location.href,
            title: document.title,
            selects: [],
            buttons: [],
            options: [],
            dataAttrs: [],
            iframes: [],
            playlistTitles: [],
            videos: []
        };

        try{
            var pts = document.querySelectorAll('.playlist-title');
            for(var i=0;i<pts.length;i++){
                out.playlistTitles.push({
                    text: norm(pts[i].textContent).substring(0, 80),
                    cls: String(pts[i].className||'').substring(0,120),
                    kind: classifyGroup(norm(pts[i].textContent))
                });
            }
        }catch(e){}

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
        for (var i = 0; i < btns.length && i < 200; i++) {
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

        var vids = document.querySelectorAll('video, source');
        for (var i = 0; i < vids.length && i < 20; i++) {
            out.videos.push({
                tag: vids[i].tagName.toLowerCase(),
                src: String(vids[i].src || vids[i].getAttribute('src') || '').substring(0, 300),
                type: String(vids[i].type || '')
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
    [500, 1500, 3000, 5000, 8000, 12000].forEach(function(d){
        setTimeout(scanExistingVideos, d);
    });
    [900, 2200, 4000, 7000, 11000].forEach(function(d){
        setTimeout(autoStartPlayback, d);
    });
    })();
    """
}
