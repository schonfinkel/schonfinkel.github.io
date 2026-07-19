;; package --- Summary:
;; graph.el --- build the org-roam notes graph
;;; Commentary:
;;;
;;; Reads notes/org-roam.db with the built-in sqlite bindings, computes a
;;; degree-based centrality and label-propagation communities, then writes
;;; static/graph.json and embeds the JSON into static/html/graph.html.
;;;
;;; How to run this:
;;; * emacs --batch --load graph.el --funcall schonfinkel/generate-graph
;;;
;;; Code:

(require 'color)
(require 'json)
(require 'subr-x)

(defconst schonfinkel/graph-root
  (file-name-directory
   (expand-file-name (or load-file-name buffer-file-name "graph.el")))
  "Repository root, resolved from this file's location.")

(defconst schonfinkel/graph-db-file
  (concat schonfinkel/graph-root "notes/org-roam.db"))
(defconst schonfinkel/graph-json-file
  (concat schonfinkel/graph-root "static/graph.json"))
(defconst schonfinkel/graph-html-file
  (concat schonfinkel/graph-root "static/html/graph.html"))

;;; Helpers:

(defun schonfinkel/graph--unquote (str)
  "Strip the literal surrounding double quotes org-roam stores in STR."
  (string-trim str "\"+" "\"+"))

(defun schonfinkel/graph--patch-line (file regexp replacement)
  "Replace the first line of FILE matching REGEXP with REPLACEMENT."
  (let ((coding-system-for-read 'utf-8)
        (coding-system-for-write 'utf-8))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (if (re-search-forward regexp nil t)
          (progn
            (replace-match replacement t t)
            (write-region nil nil file))
        (message "WARNING: no line matching %s in %s" regexp file)))))

;;; Graph construction:

(defun schonfinkel/graph--query (db)
  "Return (NODES . LINKS) read from the org-roam database DB.
NODES are (file id title) rows for top-level nodes; LINKS are deduplicated
\(source . dest) id pairs whose endpoints are both top-level nodes."
  (let* ((rows (sqlite-select db "SELECT file, id, title FROM nodes WHERE level = 0"))
         (raw (sqlite-select db "SELECT n1.id, n2.id FROM nodes AS n1
                                 JOIN links ON n1.id = links.source
                                 JOIN nodes AS n2 ON links.dest = n2.id
                                 WHERE links.type = '\"id\"'"))
         (id-set (make-hash-table :test #'equal))
         (seen (make-hash-table :test #'equal))
         (links '()))
    (dolist (row rows)
      (puthash (nth 1 row) t id-set))
    (dolist (pair raw)
      (let ((src (nth 0 pair))
            (dst (nth 1 pair)))
        (when (and (gethash src id-set)
                   (gethash dst id-set)
                   (not (gethash (concat src "->" dst) seen)))
          (puthash (concat src "->" dst) t seen)
          (push (cons src dst) links))))
    (cons rows (nreverse links))))

(defun schonfinkel/graph--adjacency (links)
  "Build an undirected adjacency table (id -> neighbor ids) from LINKS."
  (let ((adjacency (make-hash-table :test #'equal)))
    (dolist (link links)
      (let ((a (car link))
            (b (cdr link)))
        (unless (equal a b)
          (unless (member b (gethash a adjacency))
            (push b (gethash a adjacency)))
          (unless (member a (gethash b adjacency))
            (push a (gethash b adjacency))))))
    adjacency))

(defun schonfinkel/graph--centrality (ids adjacency)
  "Map each id in IDS to its degree in ADJACENCY, min-max normalized to [0, 1]."
  (let ((centrality (make-hash-table :test #'equal))
        (min-deg most-positive-fixnum)
        (max-deg 0))
    (dolist (id ids)
      (let ((degree (length (gethash id adjacency))))
        (puthash id degree centrality)
        (setq min-deg (min min-deg degree)
              max-deg (max max-deg degree))))
    (let ((range (float (- max-deg min-deg))))
      (dolist (id ids)
        (puthash id
                 (if (> range 0.0)
                     (/ (- (gethash id centrality) min-deg) range)
                   0.0)
                 centrality)))
    centrality))

(defun schonfinkel/graph--communities (ids adjacency)
  "Label nodes in IDS with communities via deterministic label propagation.
Each node starts with its own label and repeatedly adopts the most frequent
label among its ADJACENCY neighbors (ties broken by the smallest label).
Labels are renumbered to a compact 0..n-1 range in first-appearance order,
because the frontend indexes an array by communityLabel."
  (let ((labels (make-hash-table :test #'equal))
        (index 0))
    (dolist (id ids)
      (puthash id index labels)
      (setq index (1+ index)))
    (let ((changed t)
          (iterations 0))
      (while (and changed (< iterations 100))
        (setq changed nil
              iterations (1+ iterations))
        (dolist (id ids)
          (let ((neighbors (gethash id adjacency)))
            (when neighbors
              (let ((counts (make-hash-table :test #'eql))
                    (best nil)
                    (best-count 0))
                (dolist (neighbor neighbors)
                  (let* ((label (gethash neighbor labels))
                         (count (1+ (gethash label counts 0))))
                    (puthash label count counts)
                    (when (or (> count best-count)
                              (and (= count best-count)
                                   (< label best)))
                      (setq best label
                            best-count count))))
                (unless (eql best (gethash id labels))
                  (puthash id best labels)
                  (setq changed t))))))))
    (let ((renumber (make-hash-table :test #'eql))
          (next 0)
          (communities (make-hash-table :test #'equal)))
      (dolist (id ids)
        (let ((label (gethash id labels)))
          (unless (gethash label renumber)
            (puthash label next renumber)
            (setq next (1+ next)))
          (puthash id (gethash label renumber) communities)))
      communities)))

(defun schonfinkel/graph--palette (n)
  "Deterministic full-spectrum palette of N hex colors."
  (let ((palette (make-vector n "#808080")))
    (dotimes (i n)
      ;; 0.5 lightness is middle-bright; 0.7 saturation is vibrant
      (let ((rgb (color-hsl-to-rgb (/ (float i) n) 0.7 0.5)))
        (aset palette i
              (format "#%02x%02x%02x"
                      (truncate (* 255.0 (nth 0 rgb)))
                      (truncate (* 255.0 (nth 1 rgb)))
                      (truncate (* 255.0 (nth 2 rgb)))))))
    palette))

(defun schonfinkel/graph--to-json (rows links centrality communities palette)
  "Serialize the graph to the node-link JSON format the D3 frontend expects."
  (let ((nodes
         (mapcar
          (lambda (row)
            (let ((id (nth 1 row))
                  (label (schonfinkel/graph--unquote (nth 2 row)))
                  (lnk (downcase
                        (file-name-base
                         (schonfinkel/graph--unquote (nth 0 row))))))
              `((label . ,label)
                (tooltip . ,label)
                (lnk . ,lnk)
                (id . ,id)
                (centrality . ,(gethash id centrality))
                (communityLabel . ,(gethash id communities))
                (color . ,(aref palette (gethash id communities))))))
          rows)))
    (json-encode
     `((directed . t)
       (multigraph . :json-false)
       (graph . ,(make-hash-table))
       (nodes . ,(vconcat nodes))
       (links . ,(vconcat
                  (mapcar (lambda (link)
                            `((source . ,(car link))
                              (target . ,(cdr link))))
                          links)))))))

;;; Entry points:

(defun schonfinkel/generate-graph ()
  "Write static/graph.json and embed it into static/html/graph.html."
  (cond
   ((not (sqlite-available-p))
    (message "Emacs was built without sqlite support, skipping graph"))
   ((not (file-exists-p schonfinkel/graph-db-file))
    (message "Error: database not found at %s" schonfinkel/graph-db-file))
   (t
    (message "Building and coloring graph...")
    (let* ((db (sqlite-open schonfinkel/graph-db-file))
           (graph (schonfinkel/graph--query db))
           (rows (car graph))
           (links (cdr graph)))
      (sqlite-close db)
      (if (null rows)
          (message "Done (graph empty).")
        (let* ((ids (mapcar (lambda (row) (nth 1 row)) rows))
               (adjacency (schonfinkel/graph--adjacency links))
               (centrality (schonfinkel/graph--centrality ids adjacency))
               (communities (schonfinkel/graph--communities ids adjacency))
               (palette (schonfinkel/graph--palette
                         (1+ (apply #'max (hash-table-values communities)))))
               (json (schonfinkel/graph--to-json
                      rows links centrality communities palette))
               (coding-system-for-write 'utf-8))
          (write-region json nil schonfinkel/graph-json-file)
          (schonfinkel/graph--patch-line
           schonfinkel/graph-html-file
           "^\\s-*var graph_data =.*$"
           (concat "var graph_data = " json))
          (message "Done (%d nodes, %d links)." (length rows) (length links))))))))

(defun schonfinkel/patch-graph-url ()
  "Point the graph's `url' variable at OUT_URL or the local public/ dir.
Replaces the old fix-html.py build step."
  (let ((url (or (getenv "OUT_URL")
                 (concat schonfinkel/graph-root "public"))))
    (schonfinkel/graph--patch-line
     schonfinkel/graph-html-file
     "^\\s-*var url =.*$"
     (format "var url = \"%s\"" url))))

(provide 'graph)
;;; graph.el ends here
