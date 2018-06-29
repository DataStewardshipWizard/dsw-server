module Specs.API.Questionnaire.Public_GET
  ( public_get
  ) where

import Data.Aeson (encode)
import Network.HTTP.Types
import Network.Wai (Application)
import Test.Hspec
import Test.Hspec.Wai hiding (shouldRespondWith)
import Test.Hspec.Wai.Matcher

import Api.Resource.Error.ErrorDTO ()
import Common.Error
import Database.DAO.PublicQuestionnaire.PublicQuestionnaireDAO
import Database.Migration.Package.Data.Packages
import Database.Migration.PublicQuestionnaire.Data.PublicQuestionnaires
import qualified
       Database.Migration.PublicQuestionnaire.PublicQuestionnaireMigration
       as PUBQTN
import Model.Context.AppContext
import Service.Questionnaire.QuestionnaireMapper

import Specs.API.Common
import Specs.Common

-- ------------------------------------------------------------------------
-- GET /questionnaires/public
-- ------------------------------------------------------------------------
public_get :: AppContext -> SpecWith Application
public_get appContext =
  describe "GET /questionnaires/public" $ do
    test_200 appContext
    test_404 appContext

-- ----------------------------------------------------
-- ----------------------------------------------------
-- ----------------------------------------------------
reqMethod = methodGet

reqUrl = "/questionnaires/public"

reqHeaders = []

reqBody = ""

-- ----------------------------------------------------
-- ----------------------------------------------------
-- ----------------------------------------------------
test_200 appContext =
  it "HTTP 200 OK" $
     -- GIVEN: Prepare expectation
   do
    let expStatus = 200
    let expHeaders = [resCtHeader] ++ resCorsHeaders
    let expDto = toDetailDTO publicQuestionnaire elixirNlPackage2Dto
    let expBody = encode expDto
     -- AND: Run migrations
    runInContextIO PUBQTN.runMigration appContext
     -- WHEN: Call API
    response <- request reqMethod reqUrl reqHeaders reqBody
     -- AND: Compare response with expetation
    let responseMatcher =
          ResponseMatcher {matchHeaders = expHeaders, matchStatus = expStatus, matchBody = bodyEquals expBody}
    response `shouldRespondWith` responseMatcher

-- ----------------------------------------------------
-- ----------------------------------------------------
-- ----------------------------------------------------
test_404 appContext =
  it "HTTP 404 NOT FOUND - entity doesn't exist" $
      -- GIVEN: Prepare expectation
   do
    let expStatus = 404
    let expHeaders = [resCtHeader] ++ resCorsHeaders
    let expDto = NotExistsError "Entity does not exist"
    let expBody = encode expDto
    -- AND: Delete public questionnaire
    runInContextIO deletePublicQuestionnaires appContext
    -- WHEN: Call APIA
    response <- request reqMethod reqUrl reqHeaders reqBody
    -- AND: Compare response with expetation
    let responseMatcher =
          ResponseMatcher {matchHeaders = expHeaders, matchStatus = expStatus, matchBody = bodyEquals expBody}
    response `shouldRespondWith` responseMatcher