module Shared

open System
open System.IO
open System.Text.RegularExpressions


let private projectRoot = __SOURCE_DIRECTORY__ |> string |> Path.GetFullPath

let private postsDirectory = Path.Join(projectRoot, "blog")
let private notesDirectory = Path.Join(projectRoot, "notes")

let private noteCreatedAt (s: String) = s.[0..13]
let private postCreatedAt (s: String) = s.[0..7]

let private rxTitle = Regex(@"\+TITLE:\s?(.+)", RegexOptions.IgnoreCase)

let check (regex: Regex) expr =
    let m = regex.Match(expr)
    if m.Success then Some(m.Groups[1].Value) else None

let private addTitle src (path: String) =
    File.ReadAllText($"{projectRoot}/{src}/{path}")
    |> check rxTitle
    |> function
        | Some t -> t
        | None -> "No title"

let posts =
    Directory.EnumerateFiles(postsDirectory)
    |> Seq.map System.IO.Path.GetFileName
    |> List.ofSeq
    |> List.filter (fun s -> s.StartsWith(".") |> not)
    |> List.sortByDescending (postCreatedAt)
    |> List.map (fun p -> (addTitle "blog" p, p))

let notes =
    Directory.EnumerateFiles(notesDirectory)
    |> Seq.map System.IO.Path.GetFileName
    |> List.ofSeq
    |> List.filter (fun s -> s.StartsWith(".") |> not)
    |> List.sortByDescending (noteCreatedAt)
    |> List.map (fun p -> (addTitle "notes" p, p))

let capitalize (s: String) =
    s.Split([| '_' |])
    |> Array.map (fun w -> (Char.ToUpper(w.[0]) |> string) + w.[1..])
    |> String.concat (" ")
