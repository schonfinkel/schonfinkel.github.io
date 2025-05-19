#load "shared.fs"

open System

let org =
    Shared.notes
    |> List.map (fun (title, fileName) -> Shared.createNote title fileName)
    |> (fun s -> String.Join("\n", s))

printfn "%s" org
