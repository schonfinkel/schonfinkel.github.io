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

let filterNames (excluded: Set<String>) (fileName: String) =
    (fileName.StartsWith(".") || Set.contains fileName excluded) |> not

let paginate size c = 
    let pages = List.chunkBySize size c
    let indexes = List.init (List.length pages) (fun x -> x + 1)
    List.zip indexes pages

let createItem dir interval title (fileName: String) =
    let (s, e) = interval
    let createdAt = fileName.[s..e]
    let date = $"{createdAt.[0..3]}-{createdAt.[4..5]}-{createdAt.[6..7]}"
    let file = fileName.Replace(".org", "")

    $"""
    <div class="stub">
      <h2>
        <a href="./{dir}/{file}.html"> {title} </a>
      </h2>
      <small>{date}</small>
    </div>
    """

let createNote title fileName =
    Shared.createItem "notes" (0, 13) title fileName

let createPost title fileName =
    Shared.createItem "blog" (0, 13) title fileName

let posts =
    let exclude = Set.empty |> Set.add "rss.org"

    Directory.EnumerateFiles(postsDirectory)
    |> Seq.map System.IO.Path.GetFileName
    |> List.ofSeq
    |> List.filter (filterNames exclude)
    |> List.sortByDescending (postCreatedAt)
    |> List.map (fun p -> (addTitle "blog" p, p))

let notes =
    let exclude = Set.empty |> Set.add "org-roam.db"

    Directory.EnumerateFiles(notesDirectory)
    |> Seq.map System.IO.Path.GetFileName
    |> List.ofSeq
    |> List.filter (filterNames exclude)
    |> List.sortByDescending (noteCreatedAt)
    |> List.map (fun p -> (addTitle "notes" p, p))
