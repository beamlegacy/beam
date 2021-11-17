import {
  BeamDocument,
  BeamLocation, BeamWebkit,
  MessageHandlers
} from "../../../../Helpers/Utils/Web/BeamTypes";
import { PointAndShoot } from "../PointAndShoot";
import {
  BeamWindowMock,
  MessageHandlerMock
} from "../../../../Helpers/Utils/Web/Test/Mock/BeamWindowMock";
import { BeamLocationMock } from "../../../../Helpers/Utils/Web/Test/Mock/BeamLocationMock";
import { BeamDocumentMock } from "../../../../Helpers/Utils/Web/Test/Mock/BeamDocumentMock";


export class PNSWindowMock extends BeamWindowMock<MessageHandlers> {
  create(
    doc: BeamDocument,
    location: Location
  ): BeamWindowMock<MessageHandlers> {
    return new PNSWindowMock(doc, location);
  }

  pns: PointAndShoot;

  constructor(doc: BeamDocument = new BeamDocumentMock(), location: BeamLocation = new BeamLocationMock()) {
    super(doc, location);
  }

  webkit: BeamWebkit<MessageHandlers> = {
    messageHandlers: {
      pointAndShoot_frameBounds: new MessageHandlerMock()
    }
  };
}
