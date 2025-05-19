#load "shared.fs"

open System

let filterNames (n: String) =
    n.Contains("draft") || n.Contains("rss") |> not

let org =
    Shared.posts
    |> List.filter (fun (_title, fileName) -> filterNames (fileName))
    |> List.map (fun (title, fileName) -> Shared.createPost title fileName)
    |> (fun s -> String.Join("\n", s))

printfn "%s" org
