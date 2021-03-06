module Mobster exposing (MobsterOperation(..), MobsterData, updateMoblist, empty, nextDriverNavigator, Role(..), mobsters, Mobster, add, rotate, decode, MobsterWithRole, randomizeMobsters, reorder)

import Array
import Maybe
import Array.Extra
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Json.Decode.Pipeline as Pipeline exposing (required, optional, hardcoded)
import Random.List
import Random


type MobsterOperation
    = MoveUp Int
    | MoveDown Int
    | Remove Int
    | SetNextDriver Int
    | SkipTurn
    | Bench Int
    | RotateIn Int
    | Add String
    | Reorder (List String)


type alias MobsterData =
    { mobsters : List String
    , inactiveMobsters : List String
    , nextDriver : Int
    }


decoder : Decoder MobsterData
decoder =
    Pipeline.decode MobsterData
        |> required "mobsters" (Decode.list Decode.string)
        |> optional "inactiveMobsters" (Decode.list Decode.string) []
        |> required "nextDriver" (Decode.int)


decode : Encode.Value -> Result String MobsterData
decode data =
    Decode.decodeValue decoder data


randomizeMobsters : MobsterData -> Random.Generator (List String)
randomizeMobsters mobsterData =
    Random.List.shuffle mobsterData.mobsters


updateMoblist : MobsterOperation -> MobsterData -> MobsterData
updateMoblist moblistOperation moblist =
    case moblistOperation of
        MoveUp mobsterIndex ->
            moveUp mobsterIndex moblist

        MoveDown mobsterIndex ->
            moveDown mobsterIndex moblist

        Remove mobsterIndex ->
            remove mobsterIndex moblist

        SetNextDriver index ->
            setNextDriver index moblist

        SkipTurn ->
            setNextDriver (nextIndex moblist.nextDriver moblist) moblist

        Bench mobsterIndex ->
            bench mobsterIndex moblist

        RotateIn mobsterIndex ->
            rotateIn mobsterIndex moblist

        Add mobsterName ->
            add mobsterName moblist

        Reorder reorderedMobsters ->
            reorder reorderedMobsters moblist


reorder : List String -> MobsterData -> MobsterData
reorder shuffledMobsters mobsterData =
    { mobsterData | mobsters = shuffledMobsters, nextDriver = 0 }


empty : MobsterData
empty =
    { mobsters = [], inactiveMobsters = [], nextDriver = 0 }


add : String -> MobsterData -> MobsterData
add mobster list =
    { list | mobsters = (List.append list.mobsters [ mobster ]) }


type alias DriverNavigator =
    { driver : Mobster
    , navigator : Mobster
    }


nextDriverNavigator : MobsterData -> DriverNavigator
nextDriverNavigator mobsterData =
    let
        list =
            asMobsterList mobsterData

        mobstersAsArray =
            Array.fromList list

        maybeDriver =
            Array.get mobsterData.nextDriver mobstersAsArray

        driver =
            case maybeDriver of
                Just justDriver ->
                    justDriver

                Nothing ->
                    { name = "", index = -1 }

        navigatorIndex =
            nextIndex mobsterData.nextDriver mobsterData

        maybeNavigator =
            Array.get navigatorIndex mobstersAsArray

        navigator =
            case maybeNavigator of
                Just justNavigator ->
                    justNavigator

                Nothing ->
                    driver
    in
        { driver = driver
        , navigator = navigator
        }


nextIndex : Int -> MobsterData -> Int
nextIndex currentIndex mobsterData =
    let
        mobSize =
            List.length mobsterData.mobsters

        index =
            if mobSize == 0 then
                0
            else
                (currentIndex + 1) % mobSize
    in
        index


rotate : MobsterData -> MobsterData
rotate mobsterData =
    { mobsterData | nextDriver = (nextIndex mobsterData.nextDriver mobsterData) }


moveDown : Int -> MobsterData -> MobsterData
moveDown itemIndex list =
    moveUp (itemIndex + 1) list


moveUp : Int -> MobsterData -> MobsterData
moveUp itemIndex list =
    let
        asArray =
            Array.fromList list.mobsters

        maybeItemToMove =
            Array.get itemIndex asArray

        maybeNeighboringItem =
            Array.get (itemIndex - 1) asArray

        updatedMobsters =
            case ( maybeItemToMove, maybeNeighboringItem ) of
                ( Just itemToMove, Just neighboringItem ) ->
                    Array.toList
                        (asArray
                            |> Array.set itemIndex neighboringItem
                            |> Array.set (itemIndex - 1) itemToMove
                        )

                ( _, _ ) ->
                    list.mobsters
    in
        { list | mobsters = updatedMobsters }


rotateIn : Int -> MobsterData -> MobsterData
rotateIn index list =
    let
        maybeMobster =
            list.inactiveMobsters
                |> Array.fromList
                |> Array.get index
    in
        case maybeMobster of
            Just nowActiveMobster ->
                let
                    updatedBench =
                        list.inactiveMobsters
                            |> Array.fromList
                            |> Array.Extra.removeAt index
                            |> Array.toList

                    updatedActive =
                        List.append list.mobsters [ nowActiveMobster ]
                in
                    { list | mobsters = updatedActive, inactiveMobsters = updatedBench }

            Nothing ->
                list


bench : Int -> MobsterData -> MobsterData
bench index list =
    let
        activeAsArray =
            (Array.fromList list.mobsters)

        maybeMobster =
            Array.get index activeAsArray
    in
        case maybeMobster of
            Just nowBenchedMobster ->
                let
                    updatedActive =
                        activeAsArray
                            |> Array.Extra.removeAt index
                            |> Array.toList

                    updatedInactive =
                        List.append list.inactiveMobsters [ nowBenchedMobster ]

                    maxIndex =
                        (List.length updatedActive) - 1

                    nextDriverInBounds =
                        if list.nextDriver > maxIndex && list.nextDriver > 0 then
                            0
                        else
                            list.nextDriver
                in
                    { list | mobsters = updatedActive, inactiveMobsters = updatedInactive, nextDriver = nextDriverInBounds }

            Nothing ->
                list


remove : Int -> MobsterData -> MobsterData
remove index list =
    let
        updatedBench =
            list.inactiveMobsters
                |> Array.fromList
                |> Array.Extra.removeAt index
                |> Array.toList
    in
        { list | inactiveMobsters = updatedBench }


type Role
    = Driver
    | Navigator


type alias Mobster =
    { name : String, index : Int }


type alias MobsterWithRole =
    { name : String, role : Maybe Role, index : Int }


type alias Mobsters =
    List MobsterWithRole


mobsterListItemToMobster : DriverNavigator -> Int -> String -> MobsterWithRole
mobsterListItemToMobster driverNavigator index mobsterName =
    let
        role =
            if index == driverNavigator.driver.index then
                Just Driver
            else if index == driverNavigator.navigator.index then
                Just Navigator
            else
                Nothing
    in
        { name = mobsterName, role = role, index = index }


asMobsterList : MobsterData -> List Mobster
asMobsterList mobsterData =
    List.indexedMap (\index mobsterName -> { name = mobsterName, index = index }) mobsterData.mobsters


mobsters : MobsterData -> Mobsters
mobsters mobsterData =
    List.indexedMap (mobsterListItemToMobster (nextDriverNavigator mobsterData)) mobsterData.mobsters


setNextDriver : Int -> MobsterData -> MobsterData
setNextDriver newDriver mobsterData =
    { mobsterData | nextDriver = newDriver }
