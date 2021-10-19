import {BeamNavigation, NavigationMessages, NavigationWindow} from "./BeamNavigation"
import {BeamWindowMock, MessageHandlerMock} from "../../../Helpers/Utils/Web/Test/Mock/BeamWindowMock"
import {BeamDocument, BeamLocation, BeamWebkit} from "../../../Helpers/Utils/Web/BeamTypes"
import {BeamLocationMock} from "../../../Helpers/Utils/Web/Test/Mock/BeamLocationMock"
import {BeamDocumentMock} from "../../../Helpers/Utils/Web/Test/Mock/BeamDocumentMock"

export class NavigationWindowMock extends BeamWindowMock<NavigationMessages> implements NavigationWindow {

  webkit: BeamWebkit<NavigationMessages> = {
    messageHandlers: {
      nav_locationChanged: new MessageHandlerMock()
    }
  }

  constructor(doc: BeamDocument = new BeamDocumentMock(), location: BeamLocation = new BeamLocationMock()) {
    super(doc, location)
  }

  create(doc: BeamDocument, location: BeamLocation): NavigationWindowMock {
    return new NavigationWindowMock(doc, location)
  }
}

describe("BeamNavigation", () => {

  const win = new NavigationWindowMock()
  const beamNavigation = new BeamNavigation(win)

  test("recognizes Google URLs", () => {
    expect(beamNavigation.isGoogleUrl("https://meet.google.com")).toBe(true)
    expect(beamNavigation.isGoogleUrl("https://mail.google.com")).toBe(true)
    expect(beamNavigation.isGoogleUrl("https://docs.google.com")).toBe(true)
  })

  test("rewrite links", () => {
    const a = document.createRange().createContextualFragment(`<a href="https://linear.app/beamapp/issue/BE-2188/beam-cant-open-httpscloudoptimizerio" target="_blank" data-saferedirecturl="https://www.google.com/url?q=https://linear.app/beamapp/issue/BE-2188/beam-cant-open-httpscloudoptimizerio&amp;source=gmail&amp;ust=1634376972756000&amp;usg=AFQjCNFdqr0KDMfXL_WNvkPcENYF08os0A">https://linear.app/beamapp/
    <wbr>
    issue/BE-2188/<span zeum4c4="PR_5_0" data-ddnwab="PR_5_0" aria-invalid="grammar" class="Lm ng">beam-cant-open-</span>
    <wbr>
    <span zeum4c4="PR_6_0" data-ddnwab="PR_6_0" aria-invalid="spelling" class="LI ng">httpscloudoptimizerio</span></a>`).querySelector("a")
    const newA = beamNavigation.linkWithoutListeners(a)
    expect(newA.outerHTML).toEqual(`<a href="https://linear.app/beamapp/issue/BE-2188/beam-cant-open-httpscloudoptimizerio" target="_blank" data-saferedirecturl="https://www.google.com/url?q=https://linear.app/beamapp/issue/BE-2188/beam-cant-open-httpscloudoptimizerio&amp;source=gmail&amp;ust=1634376972756000&amp;usg=AFQjCNFdqr0KDMfXL_WNvkPcENYF08os0A" data-beam="yes">https://linear.app/beamapp/
    <wbr>
    issue/BE-2188/<span zeum4c4="PR_5_0" data-ddnwab="PR_5_0" aria-invalid="grammar" class="Lm ng">beam-cant-open-</span>
    <wbr>
    <span zeum4c4="PR_6_0" data-ddnwab="PR_6_0" aria-invalid="spelling" class="LI ng">httpscloudoptimizerio</span></a>`)
  })
})
