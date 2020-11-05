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

        console.debug("selected range html: " + span);
        return span;
    }
    return span;
}


var beam_currentSelectedText = "";
var beam_currentSelectedHtml = "";
function beam_textSelected() {
    window.webkit.messageHandlers.beam_textSelected.postMessage({ selectedText: beam_currentSelectedText, selectedHtml: beam_currentSelectedHtml });
}



document.addEventListener('selectionchange', () => {
    beam_currentSelectedText = beam_getSelectedText();
    beam_currentSelectedHtml = beam_getSelectedHtml();
    console.debug("selected html: " + beam_currentSelectedHtml.outerHTML);
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
