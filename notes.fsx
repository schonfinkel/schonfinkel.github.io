#load "shared.fs"

open System

let createNote title (fileName: String) =
    let createdAt = fileName.[0..13]
    let date = $"{createdAt.[0..3]}-{createdAt.[4..5]}-{createdAt.[6..7]}"
    let file = fileName.Replace(".org", "")

    $"""
    <div class="stub">
      <h2>
        <a href="./notes/{file}.html"> {title} </a>
      </h2>
      <small>{date}</small>
    </div>
    """

let org =
    Shared.notes
    |> List.map (fun (title, fileName) -> createNote title fileName)
    |> (fun s -> String.Join("\n", s))

printfn "%s" org
