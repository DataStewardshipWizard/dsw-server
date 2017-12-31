module Specs.API.PackageAPISpec where

import Control.Lens
import Data.Aeson
import Data.Aeson (Value(..), (.=), object)
import Data.ByteString.Lazy
import Data.Either
import Data.Foldable
import Data.Maybe
import qualified Data.UUID as U
import Network.HTTP.Types
import Network.Wai (Application)
import Network.Wai.Test hiding (request)
import Test.Hspec
import qualified Test.Hspec.Expectations.Pretty as TP
import Test.Hspec.Wai hiding (shouldRespondWith)
import qualified Test.Hspec.Wai.JSON as HJ
import Test.Hspec.Wai.Matcher
import Text.Pretty.Simple (pPrint)
import qualified Web.Scotty as S

import Api.Resource.Package.PackageDTO
import Common.Error
import Database.DAO.Branch.BranchDAO
import Database.DAO.Package.PackageDAO
import qualified Database.Migration.Branch.BranchMigration as B
import Database.Migration.Package.Data.Package
import qualified Database.Migration.Package.PackageMigration as PKG
import Model.Package.Package
import Service.Package.PackageMapper
import Service.Package.PackageService

import Specs.API.Common
import Specs.Common

packageAPI context dspConfig = do
  let dto1 =
        PackageDTO
        { _pkgdtoId = "elixir.base:core:0.0.1"
        , _pkgdtoName = "Elixir Base Package"
        , _pkgdtoGroupId = "elixir.base"
        , _pkgdtoArtifactId = "core"
        , _pkgdtoVersion = "0.0.1"
        , _pkgdtoDescription = "Beta version"
        , _pkgdtoParentPackageId = Nothing
        }
  let dto2 =
        PackageDTO
        { _pkgdtoId = "elixir.base:core:1.0.0"
        , _pkgdtoName = "Elixir Base Package"
        , _pkgdtoGroupId = "elixir.base"
        , _pkgdtoArtifactId = "core"
        , _pkgdtoVersion = "1.0.0"
        , _pkgdtoDescription = "First Release"
        , _pkgdtoParentPackageId = Nothing
        }
  let dto3 =
        PackageDTO
        { _pkgdtoId = "elixir.nl:core-nl:1.0.0"
        , _pkgdtoName = "Elixir Netherlands"
        , _pkgdtoGroupId = "elixir.nl"
        , _pkgdtoArtifactId = "core-nl"
        , _pkgdtoVersion = "1.0.0"
        , _pkgdtoDescription = "First Release"
        , _pkgdtoParentPackageId = Just $ dto2 ^. pkgdtoId
        }
  let dto4 =
        PackageDTO
        { _pkgdtoId = "elixir.nl:core-nl:2.0.0"
        , _pkgdtoName = "Elixir Netherlands"
        , _pkgdtoGroupId = "elixir.nl"
        , _pkgdtoArtifactId = "core-nl"
        , _pkgdtoVersion = "2.0.0"
        , _pkgdtoDescription = "Second Release"
        , _pkgdtoParentPackageId = Just $ dto3 ^. pkgdtoId
        }
  with (startWebApp context dspConfig) $
    describe "PACKAGE API Spec" $
      -- ------------------------------------------------------------------------
      -- GET /packages
      -- ------------------------------------------------------------------------
     do
      describe "GET /packages" $
         -- GIVEN: Prepare request
       do
        let reqMethod = methodGet
        let reqUrl = "/packages"
        let reqHeaders = [reqAuthHeader, reqCtHeader]
        let reqBody = ""
        it "HTTP 200 OK" $ do
          liftIO $ PKG.runMigration context dspConfig fakeLogState
          -- GIVEN: Prepare expectation
          let expStatus = 200
          let expHeaders = [resCtHeader] ++ resCorsHeaders
          let expDto = [dto1, dto2, dto3, dto4]
          let expBody = encode expDto
          -- WHEN: Call API
          response <- request reqMethod reqUrl reqHeaders reqBody
          -- THEN: Compare response with expetation
          let responseMatcher =
                ResponseMatcher {matchHeaders = expHeaders, matchStatus = expStatus, matchBody = bodyEquals expBody}
          response `shouldRespondWith` responseMatcher
        createAuthTest reqMethod reqUrl [] reqBody
        createNoPermissionTest dspConfig reqMethod reqUrl [] reqBody "PM_PERM"
      -- ------------------------------------------------------------------------
      -- GET /packages?groupId={groupId}&artifactId={artifactId}
      -- ------------------------------------------------------------------------
      describe "GET /packages?groupId={groupId}&artifactId={artifactId}" $
          -- GIVEN: Prepare request
       do
        let reqMethod = methodGet
        let reqUrl = "/packages?groupId=elixir.base&artifactId=core"
        let reqHeaders = [reqAuthHeader, reqCtHeader]
        let reqBody = ""
        it "HTTP 200 OK" $ do
          liftIO $ PKG.runMigration context dspConfig fakeLogState
        -- GIVEN: Prepare expectation
          let expStatus = 200
          let expHeaders = [resCtHeader] ++ resCorsHeaders
          let expDto = [dto1, dto2]
          let expBody = encode expDto
        -- WHEN: Call API
          response <- request reqMethod reqUrl reqHeaders reqBody
        -- THEN: Compare response with expetation
          let responseMatcher =
                ResponseMatcher {matchHeaders = expHeaders, matchStatus = expStatus, matchBody = bodyEquals expBody}
          response `shouldRespondWith` responseMatcher
        createAuthTest reqMethod reqUrl [] reqBody
        createNoPermissionTest dspConfig reqMethod reqUrl [] reqBody "PM_PERM"
      -- ------------------------------------------------------------------------
      -- GET /packages/{pkgId}
      -- ------------------------------------------------------------------------
      describe "GET /packages/{pkgId}" $
         -- GIVEN: Prepare request
       do
        let reqMethod = methodGet
        let reqUrl = "/packages/elixir.base:core:1.0.0"
        let reqHeaders = [reqAuthHeader, reqCtHeader]
        let reqBody = ""
        it "HTTP 200 OK" $ do
          liftIO $ PKG.runMigration context dspConfig fakeLogState
           -- GIVEN: Prepare expectation
          let expStatus = 200
          let expHeaders = [resCtHeader] ++ resCorsHeaders
          let expDto = dto2
          let expBody = encode expDto
           -- WHEN: Call API
          response <- request reqMethod reqUrl reqHeaders reqBody
           -- THEN: Compare response with expetation
          let responseMatcher =
                ResponseMatcher {matchHeaders = expHeaders, matchStatus = expStatus, matchBody = bodyEquals expBody}
          response `shouldRespondWith` responseMatcher
        createAuthTest reqMethod reqUrl [] reqBody
        createNoPermissionTest dspConfig reqMethod reqUrl [] reqBody "PM_PERM"
        createNotFoundTest reqMethod "/packages/elixir.nonexist:nopackage:2.0.0" reqHeaders reqBody
      -- ------------------------------------------------------------------------
      -- DELETE /packages
      -- ------------------------------------------------------------------------
      describe "DELETE /packages" $
         -- GIVEN: Prepare request
       do
        let reqMethod = methodDelete
        let reqUrl = "/packages"
        let reqHeaders = [reqAuthHeader, reqCtHeader]
        let reqBody = ""
        it "HTTP 204 NO CONTENT" $ do
          liftIO $ PKG.runMigration context dspConfig fakeLogState
          liftIO $ deleteBranches context
          -- GIVEN: Prepare expectation
          let expStatus = 204
          let expHeaders = resCorsHeaders
          -- WHEN: Call API
          response <- request reqMethod reqUrl reqHeaders reqBody
          -- THEN: Find a result
          eitherPackages <- liftIO $ findPackages context
          -- AND: Compare response with expetation
          let responseMatcher =
                ResponseMatcher {matchHeaders = expHeaders, matchStatus = expStatus, matchBody = bodyEquals ""}
          response `shouldRespondWith` responseMatcher
          -- AND: Compare state in DB with expetation
          liftIO $ (isRight eitherPackages) `shouldBe` True
          let (Right packages) = eitherPackages
          liftIO $ packages `shouldBe` []
        it "HTTP 400 BAD REQUEST when package can't be deleted" $ do
          liftIO $ PKG.runMigration context dspConfig fakeLogState
          liftIO $ B.runMigration context dspConfig fakeLogState
          -- GIVEN: Prepare expectation
          let expStatus = 400
          let expHeaders = resCorsHeaders
          let expDto =
                createErrorWithErrorMessage $
                "Package 'elixir.nl:core-nl:1.0.0' can't be deleted. It's used by some branch."
          let expBody = encode expDto
          -- WHEN: Call API
          response <- request reqMethod reqUrl reqHeaders reqBody
          -- THEN: Find a result
          eitherPackages <- liftIO $ findPackages context
          -- AND: Compare response with expetation
          let responseMatcher =
                ResponseMatcher {matchHeaders = expHeaders, matchStatus = expStatus, matchBody = bodyEquals expBody}
          response `shouldRespondWith` responseMatcher
          -- AND: Compare state in DB with expetation
          liftIO $ (isRight eitherPackages) `shouldBe` True
          let (Right packages) = eitherPackages
          liftIO $ packages `shouldBe` [fromDTO dto1, fromDTO dto2, fromDTO dto3, fromDTO dto4]
        createAuthTest reqMethod reqUrl [] reqBody
        createNoPermissionTest dspConfig reqMethod reqUrl [] reqBody "PM_PERM"
      -- ------------------------------------------------------------------------
      -- DELETE /packages?groupId={groupId}&artifactId={artifactId}
      -- ------------------------------------------------------------------------
      describe "DELETE /packages?groupId={groupId}&artifactId={artifactId}" $
         -- GIVEN: Prepare request
       do
        let reqMethod = methodDelete
        let reqUrl = "/packages?groupId=elixir.nl&artifactId=core-nl"
        let reqHeaders = [reqAuthHeader, reqCtHeader]
        let reqBody = ""
        it "HTTP 204 NO CONTENT" $ do
          liftIO $ PKG.runMigration context dspConfig fakeLogState
          -- GIVEN: Prepare expectation
          let expStatus = 204
          let expHeaders = resCorsHeaders
          -- AND: Prepare DB
          liftIO $ deleteBranches context
          -- WHEN: Call API
          response <- request reqMethod reqUrl reqHeaders reqBody
          -- THEN: Find a result
          eitherPackages <- liftIO $ findPackageByGroupIdAndArtifactId context "elixir.nl" "core-nl"
          -- AND: Compare response with expetation
          let responseMatcher =
                ResponseMatcher {matchHeaders = expHeaders, matchStatus = expStatus, matchBody = bodyEquals ""}
          response `shouldRespondWith` responseMatcher
          -- AND: Compare state in DB with expetation
          liftIO $ (isRight eitherPackages) `shouldBe` True
          let (Right packages) = eitherPackages
          liftIO $ packages `shouldBe` []
        it "HTTP 400 BAD REQUEST when package can't be deleted" $ do
          liftIO $ PKG.runMigration context dspConfig fakeLogState
          liftIO $ B.runMigration context dspConfig fakeLogState
          -- GIVEN: Prepare expectation
          let expStatus = 400
          let expHeaders = resCorsHeaders
          let expDto =
                createErrorWithErrorMessage $
                "Package 'elixir.nl:core-nl:1.0.0' can't be deleted. It's used by some branch."
          let expBody = encode expDto
          -- WHEN: Call API
          response <- request reqMethod reqUrl reqHeaders reqBody
          -- THEN: Find a result
          eitherPackages <- liftIO $ findPackages context
          -- AND: Compare response with expetation
          let responseMatcher =
                ResponseMatcher {matchHeaders = expHeaders, matchStatus = expStatus, matchBody = bodyEquals expBody}
          response `shouldRespondWith` responseMatcher
          -- AND: Compare state in DB with expetation
          liftIO $ (isRight eitherPackages) `shouldBe` True
          let (Right packages) = eitherPackages
          liftIO $ packages `shouldBe` [fromDTO dto1, fromDTO dto2, fromDTO dto3, fromDTO dto4]
        createAuthTest reqMethod reqUrl [] reqBody
        createNoPermissionTest dspConfig reqMethod reqUrl [] reqBody "PM_PERM"
      -- ------------------------------------------------------------------------
      -- DELETE /packages/{pkgId}
      -- ------------------------------------------------------------------------
      describe "DELETE /packages/{pkgId}" $
         -- GIVEN: Prepare request
       do
        let reqMethod = methodDelete
        let reqUrl = "/packages/elixir.nl:core-nl:2.0.0"
        let reqHeaders = [reqAuthHeader, reqCtHeader]
        let reqBody = ""
        it "HTTP 204 NO CONTENT" $ do
          liftIO $ PKG.runMigration context dspConfig fakeLogState
        -- GIVEN: Prepare expectation
          let expStatus = 204
          let expHeaders = resCorsHeaders
        -- WHEN: Call API
          response <- request reqMethod reqUrl reqHeaders reqBody
        -- THEN: Find a result
          eitherPackage <- liftIO $ getPackageById context "elixir.nl:core-nl:2.0.0"
        -- AND: Compare response with expetation
          let responseMatcher =
                ResponseMatcher {matchHeaders = expHeaders, matchStatus = expStatus, matchBody = bodyEquals ""}
          response `shouldRespondWith` responseMatcher
        -- AND: Compare state in DB with expetation
          liftIO $ (isLeft eitherPackage) `shouldBe` True
          let (Left (NotExistsError _)) = eitherPackage
        -- AND: We have to end with expression (if there is another way, how to do it, please fix it)
          liftIO $ True `shouldBe` True
        it "HTTP 400 BAD REQUEST when package can't be deleted" $
          -- GIVEN: Prepare request
         do
          let reqUrl = "/packages/elixir.nl:core-nl:1.0.0"
          -- AND: Prepare DB
          liftIO $ PKG.runMigration context dspConfig fakeLogState
          liftIO $ B.runMigration context dspConfig fakeLogState
          -- AND: Prepare expectation
          let expStatus = 400
          let expHeaders = resCorsHeaders
          let expDto =
                createErrorWithErrorMessage $
                "Package 'elixir.nl:core-nl:1.0.0' can't be deleted. It's used by some branch."
          let expBody = encode expDto
          -- WHEN: Call API
          response <- request reqMethod reqUrl reqHeaders reqBody
          -- THEN: Find a result
          eitherPackages <- liftIO $ findPackages context
          -- AND: Compare response with expetation
          let responseMatcher =
                ResponseMatcher {matchHeaders = expHeaders, matchStatus = expStatus, matchBody = bodyEquals expBody}
          response `shouldRespondWith` responseMatcher
          -- AND: Compare state in DB with expetation
          liftIO $ (isRight eitherPackages) `shouldBe` True
          let (Right packages) = eitherPackages
          liftIO $ packages `shouldBe` [fromDTO dto1, fromDTO dto2, fromDTO dto3, fromDTO dto4]
        createAuthTest reqMethod reqUrl [] reqBody
        createNoPermissionTest dspConfig reqMethod reqUrl [] reqBody "PM_PERM"
        createNotFoundTest reqMethod "/packages/elixir.nonexist:nopackage:2.0.0" reqHeaders reqBody
