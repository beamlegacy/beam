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

var beam_currentSelectedText = "";
function beam_textSelected() {
    window.webkit.messageHandlers.beam_textSelected.postMessage({ selectedText: beam_currentSelectedText });
}

document.addEventListener('selectionchange', () => {
    var text = beam_getSelectedText();
    beam_currentSelectedText = text;
});

document.addEventListener('select', () => {
    var text = beam_getSelectedText();
    beam_currentSelectedText = text;
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
