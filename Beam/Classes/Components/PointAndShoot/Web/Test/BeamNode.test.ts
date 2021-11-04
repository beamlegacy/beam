import { BeamHTMLElementMock } from "../../../../Helpers/Utils/Web/Test/Mock/BeamHTMLElementMock"
import { BeamTextMock } from "../../../../Helpers/Utils/Web/Test/Mock/BeamTextMock"


jest.mock("debounce", () => ({
  debounce: jest.fn(fn => {
    return fn.apply(this)
  })
}))

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
  expect(p.toString()).toEqual("<p><b>MEAN</b> (<a href=\"/wiki/MongoDB\">MongoDB</a></p>")
})

test("contains", () => {
  const parent = new BeamHTMLElementMock("div")
  const child = new BeamHTMLElementMock("p")
  const parentSibling = new BeamHTMLElementMock("div")
  parent.appendChild(child)

  expect(parent.contains(child)).toEqual(true)
  expect(parent.contains(parent)).toEqual(true)
  expect(parentSibling.contains(child)).toEqual(false)
  expect(child.contains(parent)).toEqual(false)
})

test("parentElement", () => {
  const parent = new BeamHTMLElementMock("div")
  const child = new BeamHTMLElementMock("p")
  expect(child.parentElement).toBeUndefined()
  expect(parent.parentElement).toBeUndefined()

  parent.appendChild(child)
  expect(child.parentElement).toEqual(parent)
  expect(parent.parentElement).toBeUndefined()

  parent.removeChild(child)
  expect(child.parentElement).toBeNull()
  expect(parent.parentElement).toBeUndefined()
})
