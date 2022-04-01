import {
  BeamLocation, BeamWebkit,
  MessageHandlers
} from "@beam/native-beamtypes"
import { PointAndShoot } from "../src/PointAndShoot"
import {
  BeamWindowMock,
  MessageHandlerMock,
  BeamLocationMock,
  BeamDocumentMock } from "@beam/native-testmock"


export class PNSWindowMock extends BeamWindowMock<MessageHandlers> {
  create(
    doc: BeamDocumentMock,
    location: Location
  ): BeamWindowMock<MessageHandlers> {
    return new PNSWindowMock(doc, location)
  }

  pns: PointAndShoot

  constructor(doc: BeamDocumentMock = new BeamDocumentMock(), location: BeamLocation = new BeamLocationMock()) {
    super(doc, location)
  }

  webkit: BeamWebkit<MessageHandlers> = {
    messageHandlers: {
      pointAndShoot_frameBounds: new MessageHandlerMock()
    }
  }
}
