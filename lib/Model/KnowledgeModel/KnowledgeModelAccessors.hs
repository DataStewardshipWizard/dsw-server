module Model.KnowledgeModel.KnowledgeModelAccessors where

import Control.Lens
import Control.Lens.Traversal
import Data.List
import Data.Maybe (fromMaybe)
import Data.UUID
import GHC.Generics

import LensesConfig
import Model.Common
import Model.KnowledgeModel.KnowledgeModel

getChapterIds :: KnowledgeModel -> [UUID]
getChapterIds km = km ^.. chapters . traverse . uuid

kmChangeChapterIdsOrder :: ([Chapter] -> Identity [UUID]) -> KnowledgeModel -> Identity KnowledgeModel
kmChangeChapterIdsOrder convert km = Identity $ km & chapters .~ orderedChapters
  where
    ids :: Identity [UUID]
    ids = convert (km ^. chapters)
    orderedChapters :: [Chapter]
    orderedChapters = concatMap getChapterByUuid (runIdentity ids)
    getChapterByUuid :: UUID -> [Chapter]
    getChapterByUuid chUuid = filter (\x -> x ^. uuid == chUuid) (km ^. chapters)

getAllChapters :: KnowledgeModel -> [Chapter]
getAllChapters km = km ^. chapters

getChapterByUuid :: KnowledgeModel -> UUID -> Maybe Chapter
getChapterByUuid km chapterUuid = find (\ch -> ch ^. uuid == chapterUuid) (getAllChapters km)

isThereAnyChapterWithGivenUuid :: KnowledgeModel -> UUID -> Bool
isThereAnyChapterWithGivenUuid km chUuid = chUuid `elem` (getChapterUuid <$> getAllChapters km)
  where
    getChapterUuid chapter = chapter ^. uuid

------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
getQuestionIds :: Chapter -> [UUID]
getQuestionIds ch = ch ^.. questions . traverse . uuid

chChangeQuestionIdsOrder :: ([Question] -> Identity [UUID]) -> Chapter -> Identity Chapter
chChangeQuestionIdsOrder convert ch = Identity $ ch & questions .~ orderedQuestions
  where
    ids :: Identity [UUID]
    ids = convert (ch ^. questions)
    orderedQuestions :: [Question]
    orderedQuestions = concatMap getQuestionByUuid (runIdentity ids)
    getQuestionByUuid :: UUID -> [Question]
    getQuestionByUuid qUuid = filter (\x -> x ^. uuid == qUuid) (ch ^. questions)

getAllQuestions :: KnowledgeModel -> [Question]
getAllQuestions km = go (km ^.. chapters . traverse . questions . traverse)
  where
    go :: [Question] -> [Question]
    go [] = []
    go questions = questions ++ (go . concat $ getNestedQuestions <$> questions)
    getNestedQuestions :: Question -> [Question]
    getNestedQuestions Question {_questionAnswers = (Just answers)} = concat $ _answerFollowUps <$> answers
    getNestedQuestions Question {_questionAnswers = Nothing} = []

getQuestionByUuid :: KnowledgeModel -> UUID -> Maybe Question
getQuestionByUuid km questionUuid = find (\q -> q ^. uuid == questionUuid) (getAllQuestions km)

getAllQuestionsForChapterUuid :: KnowledgeModel -> UUID -> [Question]
getAllQuestionsForChapterUuid km chapterUuid =
  case getChapterByUuid km chapterUuid of
    Just chapter -> chapter ^. questions
    Nothing -> []

getAllQuestionsForAnswerUuid :: KnowledgeModel -> UUID -> [Question]
getAllQuestionsForAnswerUuid km answerUuid =
  case getAnswerByUuid km answerUuid of
    Just answer -> answer ^. followUps
    Nothing -> []

isThereAnyQuestionWithGivenUuid :: KnowledgeModel -> UUID -> Bool
isThereAnyQuestionWithGivenUuid km qUuid = qUuid `elem` (getQuestionUuid <$> getAllQuestions km)
  where
    getQuestionUuid question = question ^. uuid

------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
getAnwerIds :: Question -> Maybe [UUID]
getAnwerIds Question {_questionAnswers = Just answers} = Just $ answers ^.. traverse . uuid
getAnwerIds Question {_questionAnswers = Nothing} = Nothing

qChangeAnwerIdsOrder :: (Maybe [Answer] -> Identity (Maybe [UUID])) -> Question -> Identity Question
qChangeAnwerIdsOrder convert q = Identity $ q & answers .~ orderedAnwers
  where
    ids :: Identity (Maybe [UUID])
    ids = convert (q ^. answers)
    orderedAnwers :: Maybe [Answer]
    orderedAnwers =
      case (runIdentity ids) of
        Just uuids -> Just $ concatMap getAnswerByUuid uuids
        Nothing -> (q ^. answers)
    getAnswerByUuid :: UUID -> [Answer]
    getAnswerByUuid ansUuid =
      case q ^. answers of
        Just as -> filter (\x -> x ^. uuid == ansUuid) as
        Nothing -> []

getAllAnswers :: KnowledgeModel -> [Answer]
getAllAnswers km = concat $ getAnswer <$> getAllQuestions km
  where
    getAnswer :: Question -> [Answer]
    getAnswer question = fromMaybe [] (question ^. answers)

getAnswerByUuid :: KnowledgeModel -> UUID -> Maybe Answer
getAnswerByUuid km answerUuid = find (\ans -> ans ^. uuid == answerUuid) (getAllAnswers km)

getAllAnswersForQuestionUuid :: KnowledgeModel -> UUID -> [Answer]
getAllAnswersForQuestionUuid km questionUuid =
  case getQuestionByUuid km questionUuid of
    Just question -> fromMaybe [] (question ^. answers)
    Nothing -> []

isThereAnyAnswerWithGivenUuid :: KnowledgeModel -> UUID -> Bool
isThereAnyAnswerWithGivenUuid km ansUuid = ansUuid `elem` (getAnswerUuid <$> getAllAnswers km)
  where
    getAnswerUuid answer = answer ^. uuid

------------------------------------------------------------------------------------------
getFollowUpIds :: Answer -> [UUID]
getFollowUpIds ans = ans ^.. followUps . traverse . uuid

ansChangeFollowUpIdsOrder :: ([Question] -> Identity [UUID]) -> Answer -> Identity Answer
ansChangeFollowUpIdsOrder convert ans = Identity $ ans & followUps .~ orderedFollowUps
  where
    ids :: Identity [UUID]
    ids = convert (ans ^. followUps)
    orderedFollowUps :: [Question]
    orderedFollowUps = concatMap getFollowUpsByUuid (runIdentity ids)
    getFollowUpsByUuid :: UUID -> [Question]
    getFollowUpsByUuid fuqUuid = filter (\x -> x ^. uuid == fuqUuid) (ans ^. followUps)

------------------------------------------------------------------------------------------
getExpertIds :: Question -> [UUID]
getExpertIds q = q ^.. experts . traverse . uuid

qChangeExpertIdsOrder :: ([Expert] -> Identity [UUID]) -> Question -> Identity Question
qChangeExpertIdsOrder convert q = Identity $ q & experts .~ orderedExperts
  where
    ids :: Identity [UUID]
    ids = convert (q ^. experts)
    orderedExperts :: [Expert]
    orderedExperts = concatMap getExpertByUuid (runIdentity ids)
    getExpertByUuid :: UUID -> [Expert]
    getExpertByUuid expUuid = filter (\x -> x ^. uuid == expUuid) (q ^. experts)

getAllExperts :: KnowledgeModel -> [Expert]
getAllExperts km = concat $ getExpert <$> getAllQuestions km
  where
    getExpert :: Question -> [Expert]
    getExpert question = question ^. experts

getExpertByUuid :: KnowledgeModel -> UUID -> Maybe Expert
getExpertByUuid km expertUuid = find (\exp -> exp ^. uuid == expertUuid) (getAllExperts km)

getAllExpertsForQuestionUuid :: KnowledgeModel -> UUID -> [Expert]
getAllExpertsForQuestionUuid km questionUuid =
  case getQuestionByUuid km questionUuid of
    Just question -> question ^. experts
    Nothing -> []

isThereAnyExpertWithGivenUuid :: KnowledgeModel -> UUID -> Bool
isThereAnyExpertWithGivenUuid km expUuid = expUuid `elem` (getExpertUuid <$> getAllExperts km)
  where
    getExpertUuid expert = expert ^. uuid

------------------------------------------------------------------------------------------
getReferenceIds :: Question -> [UUID]
getReferenceIds q = q ^.. references . traverse . uuid

qChangeReferenceIdsOrder :: ([Reference] -> Identity [UUID]) -> Question -> Identity Question
qChangeReferenceIdsOrder convert q = Identity $ q & references .~ orderedReferences
  where
    ids :: Identity [UUID]
    ids = convert (q ^. references)
    orderedReferences :: [Reference]
    orderedReferences = concatMap getReferenceByUuid (runIdentity ids)
    getReferenceByUuid :: UUID -> [Reference]
    getReferenceByUuid refUuid = filter (\x -> x ^. uuid == refUuid) (q ^. references)

getAllReferences :: KnowledgeModel -> [Reference]
getAllReferences km = concat $ getReference <$> getAllQuestions km
  where
    getReference :: Question -> [Reference]
    getReference question = question ^. references

getReferenceByUuid :: KnowledgeModel -> UUID -> Maybe Reference
getReferenceByUuid km referenceUuid = find (\ref -> ref ^. uuid == referenceUuid) (getAllReferences km)

getAllReferencesForQuestionUuid :: KnowledgeModel -> UUID -> [Reference]
getAllReferencesForQuestionUuid km questionUuid =
  case getQuestionByUuid km questionUuid of
    Just question -> question ^. references
    Nothing -> []

isThereAnyReferenceWithGivenUuid :: KnowledgeModel -> UUID -> Bool
isThereAnyReferenceWithGivenUuid km refUuid = refUuid `elem` (getReferenceUuid <$> getAllReferences km)
  where
    getReferenceUuid reference = reference ^. uuid
