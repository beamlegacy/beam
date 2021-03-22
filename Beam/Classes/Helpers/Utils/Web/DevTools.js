let devtools;

function devtoolsOpen() {
    const body = document.body;
    const source = body.innerHTML;
    body.style = "display:flex";
    body.innerHTML = `<div id="document" style="flex:1">${source}</div>
    <div id="devtools" style="height:100vh;overflow:auto">
    <textarea style="height:100%">${source}</textarea>
</div>`;
    devtools = document.getElementById("devtools");
}

function devtoolsHide() {
    document.body.innerHTML = document.getElementById("document").innerHTML;
    devtools = null;
}

document.addEventListener("keypress", (event) => {
    console.log("code", event.code);
    if (event.code === "KeyI") {
        if (devtools) {
            devtoolsHide();
        } else {
            devtoolsOpen();
        }
    }
});

console.log("DevTools loaded")