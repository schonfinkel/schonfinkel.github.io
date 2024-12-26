#load "shared.fs"

open System

let createPost (fileName: String) =
    let createdAt = fileName.[0..7]
    let date = $"{createdAt.[0..3]}-{createdAt.[4..5]}-{createdAt.[6..7]}"
    let name = fileName.[9..].Replace(".org", "")
    let slug = name.Replace("_", "-")
    let title = Shared.capitalize name

    $"+ [[./blog/{fileName}][{title}]]"

let org = Shared.posts |> List.map (createPost) |> (fun s -> String.Join("\n", s))
printfn "%s" org
