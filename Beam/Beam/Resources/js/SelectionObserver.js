style = document.createElement('style');
document.head.appendChild(style);
stylesheet = style.sheet;

function css(selector,property,value)
{
    try{ stylesheet.insertRule(selector+' {'+property+':'+value+'}',stylesheet.cssRules.length); }
    catch(err){}
}

function beam_getSelectedText() {
    if (window.getSelection) {
        return window.getSelection().toString();
    } else if (document.selection) {
        return document.selection.createRange().text;
    }
    return '';
}

function beam_getSelectedHtml() {
    var span = document.createElement('span')
    span.innerHTML = "";

    var selection = document.selection;
    if (window.getSelection) {
        selection = window.getSelection();
    }
    if (selection) {
        for (let i = 0; i < selection.rangeCount; i++) {
          var cloned = selection.getRangeAt(i).cloneContents();

          span.append(cloned);
        }

        //console.debug("selected range html: " + span);
        return span;
    }
    return span;
}


var beam_currentSelectedText = "";
var beam_currentSelectedHtml = "";
function beam_textSelected() {
    window.webkit.messageHandlers.beam_textSelected.postMessage({ selectedText: beam_currentSelectedText, selectedHtml: beam_currentSelectedHtml.innerHTML });
}



document.addEventListener('selectionchange', () => {
    beam_currentSelectedText = beam_getSelectedText();
    beam_currentSelectedHtml = beam_getSelectedHtml();
    //console.debug("selected html: " + beam_currentSelectedHtml.outerHTML);
});

document.addEventListener('select', () => {
    beam_currentSelectedText = beam_getSelectedText();
    beam_currentSelectedHtml = beam_getSelectedHtml();
});

document.addEventListener('keyup', function(e) {
    var key = e.keyCode || e.which;
    if (key == 16) {
        beam_textSelected();
    }
});

document.addEventListener('mouseup', function() {
    // TODO: use https://github.com/timdown/rangy tp toggle CSS on the selected nodes in order to add an animation
    //console.log("Bleh")
    //console.error("Error")
    //console.warn("Warning")
    //console.debug("Debug")

    //css('::selection', "color", "#ff0000;")
    beam_textSelected();
    setTimeout(function(){
        //css('::selection', "color", "#4040ff;")
    }, 100);

});

window.addEventListener('scroll', function(e) {
    let scrollWidth = Math.max(
      document.body.scrollWidth, document.documentElement.scrollWidth,
      document.body.offsetWidth, document.documentElement.offsetWidth,
      document.body.clientWidth, document.documentElement.clientWidth
    );

    let scrollHeight = Math.max(
      document.body.scrollHeight, document.documentElement.scrollHeight,
      document.body.offsetHeight, document.documentElement.offsetHeight,
      document.body.clientHeight, document.documentElement.clientHeight
    );

    window.webkit.messageHandlers.beam_onScrolled.postMessage({ x: window.scrollX, y: window.scrollY, width: scrollWidth, height: scrollHeight })
});

//let videos = document.querySelectorAll('video');
//videos.forEach(function(video) {
//    video.addEventListener('durationchange', (event) => {
//      console.log('Video duration changed ' + video.duration.toString());
//    });
//
//    video.addEventListener('timeupdate', (event) => {
//      console.log('Video progress ' + video.currentTime.toString() + ' / ' + video.duration.toString());
//    });
//});

let video = document.querySelector('video');
if (video) {
    video.addEventListener('durationchange', (event) => {
      console.log('Video duration changed ' + video.duration.toString());
    });

    video.addEventListener('timeupdate', (event) => {
      console.log('Video progress ' + video.currentTime.toString() + ' / ' + video.duration.toString());
    });
}
