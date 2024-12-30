#load "shared.fs"

open System

let createPost title (fileName: String) =
    let createdAt = fileName.[0..7]
    let date = $"{createdAt.[0..3]}-{createdAt.[4..5]}-{createdAt.[6..7]}"
    let file = fileName.Replace(".org", "")

    $"""
    <div class="stub">
      <h2>
        <a href="./blog/{file}.html"> {title} </a>
      </h2>
      <small>{date}</small>
    </div>
    """

let filterNames (n: String) =
    n.Contains("draft") || n.Contains("rss") |> not

let org =
    Shared.posts
    |> List.filter (fun (_title, fileName) -> filterNames (fileName))
    |> List.map (fun (title, fileName) -> createPost title fileName)
    |> (fun s -> String.Join("\n", s))

printfn "%s" org
