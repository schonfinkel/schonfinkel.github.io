module Shared

open System
open System.IO

let private projectRoot = __SOURCE_DIRECTORY__ |> string |> Path.GetFullPath

let private postsDirectory = Path.Join(projectRoot, "blog")
let private notesDirectory = Path.Join(projectRoot, "notes")

let private noteCreatedAt (s: String) = s.[0..13]
let private postCreatedAt (s: String) = s.[0..7]

let posts =
    Directory.EnumerateFiles(postsDirectory)
    |> Seq.map System.IO.Path.GetFileName
    |> List.ofSeq
    |> List.filter (fun s -> s.StartsWith(".") |> not)
    |> List.sortByDescending (postCreatedAt)

let notes =
    Directory.EnumerateFiles(notesDirectory)
    |> Seq.map System.IO.Path.GetFileName
    |> List.ofSeq
    |> List.filter (fun s -> s.StartsWith(".") |> not)
    |> List.sortByDescending (noteCreatedAt)

let capitalize (s: String) =
    s.Split([| '_' |])
    |> Array.map (fun w -> (Char.ToUpper(w.[0]) |> string) + w.[1..])
    |> String.concat (" ")
