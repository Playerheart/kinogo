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
    function hasWord(t, words){
        var low = String(t||'').toLowerCase();
        for (var i=0;i<words.length;i++){ if (low.indexOf(words[i])!==-1) return true; }
        return false;
    }

    var SEASON_KW = ['сезон','season'];
    var EPISODE_KW = ['серия','серии','эпизод','episode','ep '];

    // ---------------- ОЗВУЧКИ (как было) ----------------
    function readVoices(){
        try{
            var btns=document.querySelectorAll('.playlist-dropdown button');
            var arr=[];
            for(var i=0;i<btns.length;i++){
                var t=norm(btns[i].textContent);
                if(t&&arr.indexOf(t)===-1) arr.push(t);
            }
            if(arr.length) window.webkit.messageHandlers.voiceList.postMessage(arr);
        }catch(e){}
    }

    // ---------------- СЕЗОНЫ ----------------
    function readSeasons(){
        try{
            var arr=[];
            // 1. <select> с опциями про сезон
            var selects=document.querySelectorAll('select');
            for(var s=0;s<selects.length;s++){
                var opts=selects[s].querySelectorAll('option');
                if(opts.length<1) continue;
                var hit=false;
                for(var o=0;o<opts.length;o++){
                    if(hasWord(opts[o].textContent, SEASON_KW)){hit=true;break;}
                }
                if(!hit) continue;
                for(var o=0;o<opts.length;o++){
                    var t=norm(opts[o].textContent);
                    if(t&&arr.indexOf(t)===-1) arr.push(t);
                }
                if(arr.length) break;
            }
            // 2. [data-season]
            if(arr.length===0){
                var ds=document.querySelectorAll('[data-season]');
                for(var i=0;i<ds.length;i++){
                    var v=norm(ds[i].getAttribute('data-season') || ds[i].textContent);
                    if(v&&arr.indexOf(v)===-1) arr.push(v);
                }
            }
            // 3. Классы с season/sezon
            if(arr.length===0){
                var cs=document.querySelectorAll('[class*="season"],[class*="sezon"],[id*="season"],[id*="sezon"]');
                for(var i=0;i<cs.length;i++){
                    var t=norm(cs[i].textContent);
                    if(!t||t.length>40) continue;
                    if(hasWord(t, SEASON_KW) && arr.indexOf(t)===-1) arr.push(t);
                }
            }
            // 4. Fallback по ключевому слову
            if(arr.length===0){
                var all=document.querySelectorAll('a, button, li, option, span');
                for(var i=0;i<all.length;i++){
                    var t=norm(all[i].textContent);
                    if(!t||t.length>40) continue;
                    if(hasWord(t, SEASON_KW) && arr.indexOf(t)===-1) arr.push(t);
                    if(arr.length>=30) break;
                }
            }
            if(arr.length) window.webkit.messageHandlers.seasonList.postMessage(arr);
        }catch(e){}
    }

    // ---------------- СЕРИИ ----------------
    function readEpisodes(){
        try{
            var arr=[];
            // 1. <select> с опциями про серию (пропускаем сезонный селект)
            var selects=document.querySelectorAll('select');
            for(var s=0;s<selects.length;s++){
                var opts=selects[s].querySelectorAll('option');
                if(opts.length<1) continue;
                var hasSeason=false, hasEp=false;
                for(var o=0;o<opts.length;o++){
                    var t=opts[o].textContent;
                    if(hasWord(t, SEASON_KW)) hasSeason=true;
                    if(hasWord(t, EPISODE_KW)) hasEp=true;
                }
                if(hasSeason && !hasEp) continue;
                if(!hasEp) continue;
                for(var o=0;o<opts.length;o++){
                    var t=norm(opts[o].textContent);
                    if(t&&arr.indexOf(t)===-1) arr.push(t);
                }
                if(arr.length) break;
            }
            // 2. [data-episode]
            if(arr.length===0){
                var de=document.querySelectorAll('[data-episode]');
                for(var i=0;i<de.length;i++){
                    var v=norm(de[i].getAttribute('data-episode') || de[i].textContent);
                    if(v&&arr.indexOf(v)===-1) arr.push(v);
                }
            }
            // 3. Классы с episode/seria
            if(arr.length===0){
                var cs=document.querySelectorAll('[class*="episode"],[class*="seria"],[class*="series-item"],[id*="episode"],[id*="seria"]');
                for(var i=0;i<cs.length;i++){
                    var t=norm(cs[i].textContent);
                    if(!t||t.length>40) continue;
                    if(arr.indexOf(t)===-1) arr.push(t);
                    if(arr.length>=100) break;
                }
            }
            // 4. По ключевому слову
            if(arr.length===0){
                var all=document.querySelectorAll('a, button, li, option');
                for(var i=0;i<all.length;i++){
                    var t=norm(all[i].textContent);
                    if(!t||t.length>40) continue;
                    if(hasWord(t, EPISODE_KW) && arr.indexOf(t)===-1) arr.push(t);
                    if(arr.length>=100) break;
                }
            }
            if(arr.length) window.webkit.messageHandlers.episodeList.postMessage(arr);
        }catch(e){}
    }

    // ---------------- КЛИК ----------------
    function clickByText(text, keywords){
        var target=norm(text);
        var low=target.toLowerCase();

        // 1. <option>
        var selects=document.querySelectorAll('select');
        for(var s=0;s<selects.length;s++){
            var opts=selects[s].querySelectorAll('option');
            for(var o=0;o<opts.length;o++){
                if(norm(opts[o].textContent)===target){
                    opts[o].selected=true;
                    selects[s].dispatchEvent(new Event('change',{bubbles:true}));
                    selects[s].dispatchEvent(new Event('input',{bubbles:true}));
                    return true;
                }
            }
        }
        // 2. [data-season="..."] / [data-episode="..."]
        for(var k=0;k<keywords.length;k++){
            try{
                var sel='[data-'+keywords[k]+'="'+target.replace(/"/g,'\\\\"')+'"]';
                var el=document.querySelector(sel);
                if(el){ el.click(); return true; }
            }catch(e){}
        }
        // 3. Точный текст
        var cands=document.querySelectorAll('a, button, li, [data-src]');
        for(var i=0;i<cands.length;i++){
            if(norm(cands[i].textContent)===target){
                try{cands[i].click();return true;}catch(e){}
            }
        }
        // 4. Частичное совпадение
        for(var i=0;i<cands.length;i++){
            var t=norm(cands[i].textContent).toLowerCase();
            if(t&&t.indexOf(low)!==-1){
                try{cands[i].click();return true;}catch(e){}
            }
        }
        // 5. По цифре
        var num=target.match(/\\d+/);
        if(num){
            for(var i=0;i<cands.length;i++){
                var t=norm(cands[i].textContent).toLowerCase();
                var hit=false;
                for(var k=0;k<keywords.length;k++){
                    if(t.indexOf(keywords[k])!==-1){hit=true;break;}
                }
                if(!hit) continue;
                if(t.indexOf(num[0])!==-1){
                    try{cands[i].click();return true;}catch(e){}
                }
            }
        }
        return false;
    }

    // ---------------- ДИАГНОСТИКА CINEMAR ----------------
    function collectDiag(){
        var out={ url: location.href, title: document.title, selects: [], buttons: [], options: [], dataAttrs: [], iframes: [] };

        var selects=document.querySelectorAll('select');
        for(var s=0;s<selects.length && s<20;s++){
            var opts=selects[s].querySelectorAll('option');
            var arr=[];
            for(var o=0;o<opts.length && o<60;o++){
                arr.push({
                    text: norm(opts[o].textContent).substring(0,80),
                    value: String(opts[o].value||'').substring(0,60),
                    selected: !!opts[o].selected
                });
            }
            out.selects.push({
                id: String(selects[s].id||''),
                name: String(selects[s].name||''),
                cls: String(selects[s].className||'').substring(0,120),
                count: opts.length,
                options: arr
            });
        }

        var btns=document.querySelectorAll('button, [role=button]');
        for(var i=0;i<btns.length && i<80;i++){
            out.buttons.push({
                text: norm(btns[i].textContent).substring(0,60),
                id: String(btns[i].id||''),
                cls: String(btns[i].className||'').substring(0,120)
            });
        }

        var os=document.querySelectorAll('option');
        for(var i=0;i<os.length && i<100;i++){
            out.options.push({
                text: norm(os[i].textContent).substring(0,80),
                value: String(os[i].value||'').substring(0,60),
                parentSelect: os[i].parentElement ? (os[i].parentElement.id || os[i].parentElement.name || '') : ''
            });
        }

        var da=document.querySelectorAll('[data-season],[data-episode],[data-src],[data-id],[data-translation],[data-voice]');
        for(var i=0;i<da.length && i<80;i++){
            var attr=[];
            for(var a=0;a<da[i].attributes.length;a++){
                var an=da[i].attributes[a].name;
                if(an.indexOf('data-')===0) attr.push(an+'='+da[i].attributes[a].value);
            }
            out.dataAttrs.push({
                tag: da[i].tagName.toLowerCase(),
                text: norm(da[i].textContent).substring(0,60),
                cls: String(da[i].className||'').substring(0,120),
                attrs: attr.slice(0,8)
            });
        }

        var ifr=document.querySelectorAll('iframe');
        for(var i=0;i<ifr.length && i<20;i++){
            out.iframes.push({
                src: String(ifr[i].src||'').substring(0,200),
                id: String(ifr[i].id||''),
                cls: String(ifr[i].className||'').substring(0,120)
            });
        }

        return out;
    }

    window.addEventListener('message',function(e){
        if(!e.data||!e.data.type) return;
        if(e.data.type==='selectVoice'){
            var title=document.querySelector('.playlist-title');
            if(title) title.click();
            setTimeout(function(){
                var all=document.querySelectorAll('.playlist-dropdown button');
                for(var i=0;i<all.length;i++){
                    if(norm(all[i].textContent)===e.data.text){all[i].click();return;}
                }
            },250);
        }
        if(e.data.type==='selectSeason'){
            var ok=clickByText(e.data.text, ['season','sezon']);
            if(ok){
                setTimeout(readEpisodes,600);
                setTimeout(readEpisodes,1500);
                setTimeout(readEpisodes,3000);
                setTimeout(readEpisodes,5000);
            }
        }
        if(e.data.type==='selectEpisode'){
            clickByText(e.data.text, ['episode','seria','seriya']);
        }
        if(e.data.type==='diagnose'){
            if(location.hostname.indexOf('cinemar')===-1) return;
            try{
                var report=collectDiag();
                window.webkit.messageHandlers.cinemarDiag.postMessage(JSON.stringify(report));
            }catch(err){
                try{ window.webkit.messageHandlers.cinemarDiag.postMessage('DIAG_ERROR: '+String(err)); }catch(e){}
            }
        }
    });

    setTimeout(readVoices,2000);
    setTimeout(readVoices,5000);
    setTimeout(readVoices,9000);
    setTimeout(readSeasons,1500);
    setTimeout(readSeasons,4000);
    setTimeout(readSeasons,8000);
    setTimeout(readEpisodes,2000);
    setTimeout(readEpisodes,5000);
    setTimeout(readEpisodes,9000);
    })();
    """
}
