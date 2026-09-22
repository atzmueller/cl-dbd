;;; Semantic Information Systems Group, Osnabrück University
;;; (C) 2024-2025 Martin Atzmueller

;;;; cl-dbd.asd

(asdf:defsystem #:cl-dbd
  :description "CL-DBD: DataBase-oriented Declarative DSLs"
  :author "Martin Atzmueller <martin@atzmueller.net>"
  :license  "MIT"
  :version "0.1"
  :depends-on ("cl-dbi" "fiveam")
  :serial t
  :components ((:file "package")
	       (:file "datalog")
	       (:file "relational-algebra")
	       (:file "sql-dbi-extensions")
               (:file "cl-dbd"))
  :in-order-to ((test-op (test-op "cl-dbd/tests"))))

;;; test system with: (asdf:test-system :cl-dbd)

(asdf:defsystem #:cl-dbd/tests
  :description "cl-dbd-test-system"
  :author "Martin Atzmueller <martin@atzmueller.net>"
  :license  "MIT"
  :serial t
  :depends-on ("uiop" "cl-dbd")
  :components ((:file "tests/package")
	       (:file "tests/cl-dbd-test-system")
	       (:file "tests/cl-dbd-ra-tests")
	       (:file "tests/cl-dbd-sql-tests")
               (:file "tests/cl-dbd-dl-tests"))
  :perform (asdf:test-op (o s)
			 (uiop:symbol-call
			  :fiveam
			  :run!
			  (find-symbol "CL-DBD-TEST-SYSTEM" (find-package '#:cl-dbd-test)))))
