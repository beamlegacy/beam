#!/bin/sh

# see https://everything.curl.dev/usingcurl/verbose/trace

# Single update
#curl --trace-ascii test_multipart_upload.dump http://api.beam.lvh.me/graphql \
   #-H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI2ZGU5ZjdkNy0zM2EyLTQ4NDEtODJiOC05MWJjOWRjM2JkYjUiLCJzdWIiOiI5MTMwNTQ2Yi1lZjkyLTQ4MDMtYThmNC1jYzJmOTAyNDViMGYiLCJzY3AiOiJ1c2VyIiwiYXVkIjpudWxsLCJpYXQiOjE2MzcyNDcwOTYsImV4cCI6MTYzNzg1MTg5Nn0.BIslbd-vEE9IXO3-4UNBxJErkzLbg_EIVD88pTGXreI" \
	#-F operations='{ "query" : "mutation UpdateBeamObject($id: ID!, $data: Upload, $privateKeySignature: String, $type: String, $checksum: SHA256, $previousChecksum: SHA256, $createdAt: ISO8601DateTime, $updatedAt: ISO8601DateTime, $deletedAt: ISO8601DateTime, $privateKey: String) { updateBeamObject(input: {beamObject: {id: $id, largeData: $data, privateKeySignature: $privateKeySignature, type: $type, checksum: $checksum, previousChecksum: $previousChecksum, createdAt: $createdAt, updatedAt: $updatedAt, deletedAt: $deletedAt}, privateKey: $privateKey}) { beamObject { id checksum type } errors { objectid path message }}} ", "variables" : {"id" : "295D94E1-E0DF-4ECA-93E6-8778984BCD58", "privateKeySignature" : "45cb7cb283d0b9ca64219bd0bc033c0fad461aaf6783d5be71eac2e772c3c828", "updatedAt" : "2021-11-18T15:11:41.660Z", "type" : "my_remote_object", "checksum" : "dcc4c6ad8c76d52a501a99a30883b1bbc7682a15d1e7704f2bbcf62d1b6d46c2", "createdAt" : "2021-11-18T15:11:41.660Z"}}' \
	#-F map='{ "data" : [ "variables.data" ] }' \
	#-F data='@foobar.txt'

	# -F data="this is the binary"

# Multiple updates


   #-F operations='{"query":"mutation UpdateBeamObjects($beamObjects: [BeamObjectInput!]!, $largeFiles: [Upload!], $privateKey: String) {\n  updateBeamObjects(input: {beamObjectsInput: $beamObjects, largeFiles: $largeFiles, privateKey: $privateKey}) {\n    beamObjects {\n      id\n      checksum\n      type\n      data\n    }\n    errors {\n      objectid\n      path\n      message\n    }\n  }\n}\n","variables":{"beamObjects":[{"previousChecksum":"dcc4c6ad8c76d52a501a99a30883b1bbc7682a15d1e7704f2bbcf62d1b6d46c2","checksum":"dcc4c6ad8c76d52a501a99a30883b1bbc7682a15d1e7704f2bbcf62d1b6d46c2","createdAt":"2021-11-18T15:11:41.660Z","id":"295D94E1-E0DF-4ECA-93E6-8778984BCD58","privateKeySignature":"45cb7cb283d0b9ca64219bd0bc033c0fad461aaf6783d5be71eac2e772c3c828","type":"my_remote_object","updatedAt":"2021-11-18T15:11:41.660Z","data":"VGhpcyBpcyBhbm90aGVyIGRhdGE="}]},"operationName":"UpdateBeamObjects"}' \
curl --trace-ascii test_multipart_upload.dump http://api.beam.lvh.me/graphql \
 	-H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI3YjgzOTlmNC1kMTA5LTRkY2MtYmUyNS0yNzI5ODczNzkwZDAiLCJzdWIiOiIyN2JlNjRkNi1mNzJjLTQ3MjctYmRhNi0xOTk1ZjZkMzBlMTUiLCJzY3AiOiJ1c2VyIiwiYXVkIjpudWxsLCJpYXQiOjE2Mzc1ODIwNjYsImV4cCI6MTYzODE4Njg2Nn0.fmZCXXhYezUl7dEktWgnibRWfXrTtq6xrR3k1sAuMq8" \
   -F operations='{"query":"mutation UpdateBeamObjects($beamObjects: [BeamObjectInput!]!, $largeFiles: [Upload!], $privateKey: String) {\n  updateBeamObjects(input: {beamObjectsInput: $beamObjects, largeFiles: $largeFiles, privateKey: $privateKey}) {\n    beamObjects {\n      id\n      checksum\n      type\n      data\n    }\n    errors {\n      objectid\n      path\n      message\n    }\n  }\n}\n","variables":{"beamObjects":[{"previousChecksum":"dcc4c6ad8c76d52a501a99a30883b1bbc7682a15d1e7704f2bbcf62d1b6d46c2","checksum":"dcc4c6ad8c76d52a501a99a30883b1bbc7682a15d1e7704f2bbcf62d1b6d46c2","createdAt":"2021-11-18T15:11:41.660Z", "id":"295D94E1-E0DF-4ECA-93E6-8778984BCD58","privateKeySignature":"45cb7cb283d0b9ca64219bd0bc033c0fad461aaf6783d5be71eac2e772c3c828","type":"my_remote_object","updatedAt":"2021-11-18T15:11:41.660Z"}, {"previousChecksum":"dcc4c6ad8c76d52a501a99a30883b1bbc7682a15d1e7704f2bbcf62d1b6d46c2","checksum":"dcc4c6ad8c76d52a501a99a30883b1bbc7682a15d1e7704f2bbcf62d1b6d46c2","createdAt":"2021-11-18T15:11:41.660Z", "id":"395D94E1-E0DF-4ECA-93E6-8778984BCD58","privateKeySignature":"45cb7cb283d0b9ca64219bd0bc033c0fad461aaf6783d5be71eac2e772c3c828","type":"my_remote_object","updatedAt":"2021-11-18T15:11:41.660Z"}]},"operationName":"UpdateBeamObjects"}' \
	-F map='{ "1" : [ "variables.beamObjects.0.largeData" ], "2" : [ "variables.beamObjects.1.largeData" ] }' \
	-F 1='@foobar.enc' \
	-F 2='@foobar.enc' \


	# Links for help
# https://github.com/jetruby/apollo_upload_server-ruby/blob/master/spec/apollo_upload_server/graphql_data_builder_spec.rb
