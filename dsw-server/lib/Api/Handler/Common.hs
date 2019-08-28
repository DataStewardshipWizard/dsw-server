module Api.Handler.Common where

import Control.Lens ((^.))
import Control.Monad.Logger (MonadLogger, runStdoutLoggingT)
import Control.Monad.Reader (asks, lift, liftIO, runReaderT)
import Data.Aeson ((.=), eitherDecode, encode, object)
import qualified Data.ByteString.Lazy as BSL
import Data.Maybe
import qualified Data.Text as T
import qualified Data.Text.Lazy as LT
import qualified Data.UUID as U
import Network.HTTP.Types (hContentType, notFound404)
import Network.HTTP.Types.Method (methodOptions)
import Network.HTTP.Types.Status
       (badRequest400, forbidden403, internalServerError500, ok200,
        unauthorized401)
import Network.Wai
import Web.Scotty.Trans
       (ActionT, ScottyError, addHeader, body, header, json,
        liftAndCatchIO, params, raw, request, showError, status)

import Api.Resource.Error.ErrorDTO
import Api.Resource.Error.ErrorJM ()
import Constant.Api
       (authorizationHeaderName, xDSWTraceUuidHeaderName)
import Constant.Component
import LensesConfig hiding (requestMethod)
import Localization.Locale
import Localization.Messages.Internal
import Localization.Messages.Public
import Model.Context.AppContext
import Model.Context.BaseContext
import Model.Error.Error
import Service.Token.TokenService
import Service.User.UserService
import Util.List (foldInContext)
import Util.Logger
import Util.Token
import Util.Uuid

type Endpoint = ActionT LT.Text BaseContextM ()

runInUnauthService function = do
  traceUuid <- liftIO generateUuid
  addHeader (LT.pack xDSWTraceUuidHeaderName) (LT.pack . U.toString $ traceUuid)
  appConfig <- lift $ asks _baseContextAppConfig
  localization <- lift $ asks _baseContextLocalization
  buildInfoConfig <- lift $ asks _baseContextBuildInfoConfig
  dbPool <- lift $ asks _baseContextPool
  msgChannel <- lift $ asks _baseContextMsgChannel
  httpClientManager <- lift $ asks _baseContextHttpClientManager
  let appContext =
        AppContext
        { _appContextAppConfig = appConfig
        , _appContextLocalization = localization
        , _appContextBuildInfoConfig = buildInfoConfig
        , _appContextPool = dbPool
        , _appContextMsgChannel = msgChannel
        , _appContextHttpClientManager = httpClientManager
        , _appContextTraceUuid = traceUuid
        , _appContextCurrentUser = Nothing
        }
  liftAndCatchIO $ runStdoutLoggingT $ runReaderT (runAppContextM function) appContext

runInAuthService user function = do
  traceUuid <- liftIO generateUuid
  addHeader (LT.pack xDSWTraceUuidHeaderName) (LT.pack . U.toString $ traceUuid)
  appConfig <- lift $ asks _baseContextAppConfig
  localization <- lift $ asks _baseContextLocalization
  buildInfoConfig <- lift $ asks _baseContextBuildInfoConfig
  dbPool <- lift $ asks _baseContextPool
  msgChannel <- lift $ asks _baseContextMsgChannel
  httpClientManager <- lift $ asks _baseContextHttpClientManager
  let appContext =
        AppContext
        { _appContextAppConfig = appConfig
        , _appContextLocalization = localization
        , _appContextBuildInfoConfig = buildInfoConfig
        , _appContextPool = dbPool
        , _appContextMsgChannel = msgChannel
        , _appContextHttpClientManager = httpClientManager
        , _appContextTraceUuid = traceUuid
        , _appContextCurrentUser = Just user
        }
  liftAndCatchIO $ runStdoutLoggingT $ runReaderT (runAppContextM $ function) appContext

getAuthServiceExecutor callback = getCurrentUser $ \user -> callback $ runInAuthService user

getReqDto callback = do
  reqBody <- body
  let eitherReqDto = eitherDecode reqBody
  case eitherReqDto of
    Right reqDto -> callback reqDto
    Left error -> do
      lift . logWarn $ msg _CMP_API (show error)
      sendError $ UserError _ERROR_API_COMMON__CANT_DESERIALIZE_OBJ

getCurrentUserUuid callback = do
  tokenHeader <- header (LT.pack authorizationHeaderName)
  let userUuidMaybe =
        tokenHeader >>= (\token -> Just . LT.toStrict $ token) >>= separateToken >>= getUserUuidFromToken :: Maybe T.Text
  case userUuidMaybe of
    Just userUuid -> callback (T.unpack userUuid)
    Nothing -> unauthorizedA _ERROR_SERVICE_TOKEN__UNABLE_TO_GET_TOKEN

getCurrentUser callback =
  getCurrentUserUuid $ \userUuid -> do
    eitherUser <- runInUnauthService $ getUserById userUuid
    case eitherUser of
      Right user -> callback user
      Left error -> sendError $ UnauthorizedError (_ERROR_SERVICE_TOKEN__USER_ABSENCE userUuid)

getQueryParam paramName = do
  reqParams <- params
  let mValue = lookup paramName reqParams
  case mValue of
    Just value -> return . Just . LT.toStrict $ value
    Nothing -> return Nothing

getListOfQueryParamsIfPresent :: [LT.Text] -> ActionT LT.Text BaseContextM [(T.Text, T.Text)]
getListOfQueryParamsIfPresent = Prelude.foldr go (return [])
  where
    go name monadAcc = do
      value <- extractQueryParam name
      acc <- monadAcc
      return $ maybeToList value ++ acc
    extractQueryParam name = do
      mValue <- getQueryParam name
      case mValue of
        Just value -> return $ Just (LT.toStrict name, value)
        Nothing -> return Nothing

checkPermission perm callback = do
  tokenHeader <- header (LT.pack authorizationHeaderName)
  let mUserPerms = tokenHeader >>= (\token -> Just . LT.toStrict $ token) >>= separateToken >>= getPermissionsFromToken
  case mUserPerms of
    Just userPerms ->
      if perm `Prelude.elem` userPerms
        then callback
        else forbidden
    Nothing -> forbidden

checkServiceToken callback = do
  tokenHeader <- header (LT.pack authorizationHeaderName)
  dswConfig <- lift $ asks _baseContextAppConfig
  let mToken =
        tokenHeader >>= (\token -> Just . LT.toStrict $ token) >>= separateToken >>= validateServiceToken dswConfig
  case mToken of
    Just _ -> callback
    Nothing -> unauthorizedA _ERROR_SERVICE_TOKEN__UNABLE_TO_GET_OR_VERIFY_SEVICE_TOKEN
  where
    validateServiceToken dswConfig token = do
      if token == (T.pack $ dswConfig ^. general . serviceToken)
        then Just token
        else Nothing

isLogged callback = do
  tokenHeader <- header (LT.pack authorizationHeaderName)
  callback . isJust $ tokenHeader

isAdmin callback =
  isLogged $ \userIsLogged ->
    if userIsLogged
      then getCurrentUser $ \user -> callback $ user ^. role == "ADMIN"
      else callback False

sendError :: AppError -> Endpoint
sendError (ValidationError formErrorRecords fieldErrorRecords) = do
  formErrors <- lift . foldInContext $ fmap locale formErrorRecords
  let localeTuple =
        \(k, v) -> do
          v' <- locale v
          return (k, v')
  fieldErrors <- lift . foldInContext . fmap localeTuple $ fieldErrorRecords
  status badRequest400
  json $ ValidationErrorDTO formErrors fieldErrors
sendError (UserError localeRecord) = do
  message <- lift $ locale localeRecord
  status badRequest400
  json $ UserErrorDTO message
sendError (UnauthorizedError localeRecord) = do
  message <- lift $ locale localeRecord
  status unauthorized401
  json $ UnauthorizedErrorDTO message
sendError (ForbiddenError localeRecord) = do
  message <- lift $ locale localeRecord
  status forbidden403
  json $ ForbiddenErrorDTO message
sendError (NotExistsError localeRecord) = do
  message <- lift $ locale localeRecord
  status notFound404
  json $ NotExistsErrorDTO message
sendError (GeneralServerError errorMessage) = do
  lift $ logError errorMessage
  status internalServerError500
  json $ GeneralServerErrorDTO errorMessage

sendFile :: String -> BSL.ByteString -> Endpoint
sendFile filename body = do
  let cdHeader = "attachment;filename=" ++ filename
  addHeader "Content-Disposition" (LT.pack cdHeader)
  addHeader "Content-Type" (LT.pack "application/octet-stream")
  raw body

unauthorizedA :: String -> Endpoint
unauthorizedA message = do
  status unauthorized401
  json $ object ["status" .= 401, "error" .= "Unauthorized", "message" .= message]

unauthorizedL :: String -> Response
unauthorizedL message =
  responseLBS unauthorized401 [(hContentType, "application/json; charset=utf-8")] $
  encode (object ["status" .= 401, "error" .= "Unauthorized", "message" .= message])

forbidden :: Endpoint
forbidden = do
  status forbidden403
  json $ object ["status" .= 403, "error" .= "Forbidden"]

notFoundA :: Endpoint
notFoundA = do
  request <- request
  if requestMethod request == methodOptions
    then status ok200
    else do
      lift . logInfo $ msg _CMP_API "Request does not match any route"
      status notFound404
      json $ object ["status" .= 404, "error" .= "Not Found"]

internalServerErrorA :: (ScottyError e, Monad m, MonadLogger m) => e -> ActionT e m ()
internalServerErrorA e = do
  let message = LT.unpack . showError $ e
  lift . logError $ message
  status internalServerError500
  json . GeneralServerErrorDTO $ message
