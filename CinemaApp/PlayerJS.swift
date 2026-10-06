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
    function readVoices(){
    try{
    var btns=document.querySelectorAll('.playlist-dropdown button');
    var arr=[];
    for(var i=0;i<btns.length;i++){
    var t=(btns[i].textContent||'').replace(/\\s+/g,' ').trim();
    if(t&&arr.indexOf(t)===-1) arr.push(t);
    }
    if(arr.length) window.webkit.messageHandlers.voiceList.postMessage(arr);
    }catch(e){}
    }
    window.addEventListener('message',function(e){
    if(!e.data||!e.data.type) return;
    if(e.data.type==='selectVoice'){
    var title=document.querySelector('.playlist-title');
    if(title) title.click();
    setTimeout(function(){
    var all=document.querySelectorAll('.playlist-dropdown button');
    for(var i=0;i<all.length;i++){
    if((all[i].textContent||'').replace(/\\s+/g,' ').trim()===e.data.text){all[i].click();return;}
    }
    },250);
    }
    });
    setTimeout(readVoices,2000);
    setTimeout(readVoices,5000);
    setTimeout(readVoices,9000);
    })();
    """
}
