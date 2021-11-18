#!/bin/sh

# see https://everything.curl.dev/usingcurl/verbose/trace
curl --trace-ascii test_multipart_upload.dump http://api.beam.lvh.me/graphql \
 	-H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI2ZGU5ZjdkNy0zM2EyLTQ4NDEtODJiOC05MWJjOWRjM2JkYjUiLCJzdWIiOiI5MTMwNTQ2Yi1lZjkyLTQ4MDMtYThmNC1jYzJmOTAyNDViMGYiLCJzY3AiOiJ1c2VyIiwiYXVkIjpudWxsLCJpYXQiOjE2MzcyNDcwOTYsImV4cCI6MTYzNzg1MTg5Nn0.BIslbd-vEE9IXO3-4UNBxJErkzLbg_EIVD88pTGXreI" \
	-F operations='{ "query" : "mutation UpdateBeamObject($id: ID!, $data: Upload, $privateKeySignature: String, $type: String, $checksum: SHA256, $previousChecksum: SHA256, $createdAt: ISO8601DateTime, $updatedAt: ISO8601DateTime, $deletedAt: ISO8601DateTime, $privateKey: String) { updateBeamObject(input: {beamObject: {id: $id, largeData: $data, privateKeySignature: $privateKeySignature, type: $type, checksum: $checksum, previousChecksum: $previousChecksum, createdAt: $createdAt, updatedAt: $updatedAt, deletedAt: $deletedAt}, privateKey: $privateKey}) { beamObject { id checksum type } errors { objectid path message }}} ", "variables" : {"id" : "295D94E1-E0DF-4ECA-93E6-8778984BCD58", "privateKeySignature" : "45cb7cb283d0b9ca64219bd0bc033c0fad461aaf6783d5be71eac2e772c3c828", "updatedAt" : "2021-11-18T15:11:41.660Z", "type" : "my_remote_object", "checksum" : "dcc4c6ad8c76d52a501a99a30883b1bbc7682a15d1e7704f2bbcf62d1b6d46c2", "createdAt" : "2021-11-18T15:11:41.660Z"}}' \
	-F map='{ "data" : [ "variables.data" ] }' \
	-F data='@foobar.txt'

	# -F data="this is the binary"
