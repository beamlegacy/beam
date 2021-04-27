import {BeamHTMLElementMock, BeamTextMock} from "./BeamMocks"

test("empty", () => {
  const p = new BeamHTMLElementMock("p")
  expect(p.toString()).toEqual("<p></p>")
})

test("text content", () => {
  const data = "some text"
  const text = new BeamTextMock(data)
  const p = new BeamHTMLElementMock("p")
  p.appendChild(text)
  expect(p.toString()).toEqual(`<p>${data}</p>`)
})

test("children", () => {
  const b = new BeamHTMLElementMock("b")
  b.appendChild(new BeamTextMock("MEAN"))
  const p = new BeamHTMLElementMock("p")
  p.appendChild(b)
  const lpar = new BeamTextMock(" (")
  p.appendChild(lpar)
  const a = new BeamHTMLElementMock("a", {href: "/wiki/MongoDB"})
  const mongo = new BeamTextMock("MongoDB")
  a.appendChild(mongo)
  p.appendChild(a)
  expect(p.toString()).toEqual(`<p><b>MEAN</b> (<a href="/wiki/MongoDB">MongoDB</a></p>`)
})
