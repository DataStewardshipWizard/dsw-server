module Api.Handler.Event.EventHandler where

import Network.HTTP.Types.Status (created201, noContent204)
import Web.Scotty.Trans (json, param, status)

import Api.Handler.Common
import Api.Resource.Event.EventDTO ()
import Service.Event.EventService

getEventsA :: Endpoint
getEventsA =
  checkPermission "KM_PERM" $
  getAuthServiceExecutor $ \runInAuthService -> do
    branchUuid <- param "branchUuid"
    eitherDtos <- runInAuthService $ getEvents branchUuid
    case eitherDtos of
      Right dtos -> json dtos
      Left error -> sendError error

postEventsA :: Endpoint
postEventsA =
  checkPermission "KM_PERM" $
  getAuthServiceExecutor $ \runInAuthService ->
    getReqDto $ \reqDto -> do
      branchUuid <- param "branchUuid"
      eitherEventsDto <- runInAuthService $ createEvents branchUuid reqDto
      case eitherEventsDto of
        Left appError -> sendError appError
        Right eventsDto -> do
          status created201
          json eventsDto

deleteEventsA :: Endpoint
deleteEventsA =
  checkPermission "KM_PERM" $
  getAuthServiceExecutor $ \runInAuthService -> do
    branchUuid <- param "branchUuid"
    maybeError <- runInAuthService $ deleteEvents branchUuid
    case maybeError of
      Nothing -> status noContent204
      Just error -> sendError error
