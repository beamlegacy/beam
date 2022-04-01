import {
  BeamLocation, BeamWebkit,
  MessageHandlers
} from "@beam/native-beamtypes"
import { EmbedNode } from "../src/EmbedNode"
import {
  BeamWindowMock,
  MessageHandlerMock,
  BeamLocationMock,
  BeamDocumentMock } from "@beam/native-testmock"
import { EmbedNodeUIMock } from "./EmbedNodeUIMock"


export class EmbedNodeWindowMock extends BeamWindowMock<MessageHandlers> {
  create(
    doc: BeamDocumentMock,
    location: Location
  ): BeamWindowMock<MessageHandlers> {
    return new EmbedNodeWindowMock(doc, location)
  }

  embedNode: EmbedNode<EmbedNodeUIMock>

  constructor(doc: BeamDocumentMock = new BeamDocumentMock(), location: BeamLocation = new BeamLocationMock()) {
    super(doc, location)
  }

  webkit: BeamWebkit<MessageHandlers> = {
    messageHandlers: {
      embedNode_frameBounds: new MessageHandlerMock()
    }
  }
}
