module Specs.API.Branch.APISpec where

import Test.Hspec
import Test.Hspec.Wai hiding (shouldRespondWith)

import Specs.API.Branch.Detail_DELETE
import Specs.API.Branch.Detail_GET
import Specs.API.Branch.Detail_PUT
import Specs.API.Branch.List_GET
import Specs.API.Branch.List_POST
import Specs.API.Common

branchAPI appContext =
  with (startWebApp appContext) $
  describe "BRANCH API Spec" $ do
    list_get appContext
    list_post appContext
    detail_get appContext
    detail_put appContext
    detail_delete appContext
