;;;; build-app.lisp
;;;;
;;;; This file is loaded by the Makefile to produce a quilc[.exe] binary.
;;;;

(unless *load-truename*
  (error "This file is meant to be loaded."))

#+forest-sdk (pushnew :drakma-no-ssl *features*)

(require 'asdf)

(let ((*default-pathname-defaults* (make-pathname :type nil
                                                  :name nil
                                                  :defaults *load-truename*))
      (output-file (make-pathname :name "quilc"
                                  :type #+win32 "exe" #-win32 nil))
      (system-table (make-hash-table :test 'equal))
      (entry-point "quilc::entry-point")
      (foreign-libraries nil))
  (labels ((unload-libraries ()
             ;; A dumped lisp image will use the *exact* foreign library name
             ;; that was provided at the time the image was dumped. If the
             ;; library is moved/renamed, CFFI will not try to load an
             ;; alternative, thus we unload all foreign libraries and tell CFFI
             ;; to load them at run-time allowing it to pick up alternatives.
             ;;
             ;; For a concrete example: when we build the SDK packages for
             ;; debian, the FFI library available is typically libffi.so.6. On
             ;; newer versions of debian the library is named libffi.so.7, so
             ;; when we try to load the lisp image on a newer debian version, it
             ;; fails with an error about not finding libffi.so.6.
             (setf foreign-libraries
                   (mapcar (lambda (library) (funcall (read-from-string "cffi:foreign-library-name") library))
                           (funcall (read-from-string "cffi:list-foreign-libraries") :loaded-only t)))
             (map nil (read-from-string "cffi:close-foreign-library") foreign-libraries))
           (load-libraries ()
             (pushnew #P"/usr/local/lib/rigetti/" (symbol-value (read-from-string "cffi:*foreign-library-directories*"))
                      :test #'equal)
             (map nil (read-from-string "cffi:load-foreign-library") foreign-libraries)
             (setf foreign-libraries nil))
           (option-present-p (name)
             (find name sb-ext:*posix-argv* :test 'string=))
           (make-toplevel-function (entry)
             (lambda ()
               (load-libraries)
               (with-simple-restart (abort "Abort")
                 (funcall (read-from-string entry)
                          sb-ext:*posix-argv*))))
           (load-systems-table ()
             (unless (probe-file "system-index.txt")
               (error "Generate system-index.txt with 'make system-index.txt' first."))
             (setf (gethash "quilc" system-table) (merge-pathnames "quilc.asd"))
             (with-open-file (stream "system-index.txt")
               (loop
                 :for system-file := (read-line stream nil)
                 :while system-file
                 :do (setf (gethash (pathname-name system-file) system-table)
                           (merge-pathnames system-file)))))
           (local-system-search (name)
             (values (gethash name system-table)))
           (strip-version-githash (version)
             (subseq version 0 (position #\- version :test #'eql))))
    (load-systems-table)
    (push #'local-system-search asdf:*system-definition-search-functions*)

    ;; Load systems defined by environment variable $ASDF_SYSTEMS_TO_LOAD,
    ;; or if that does not exist just load quilc
    (let ((systems (uiop:getenv "ASDF_SYSTEMS_TO_LOAD")))
      (dolist (sys (uiop:split-string (or systems "quilc") :separator " "))
        (unless (uiop:emptyp sys)
          (asdf:load-system sys))))
    ;; TODO Fix tweedledum
    ;; #-win32
    ;; (asdf:load-system "cl-quil/tweedledum")
    (funcall (read-from-string "quilc::setup-debugger"))
    (when (option-present-p "--quilc-sdk")
      (load "app/src/mangle-shared-objects.lisp"))
    (when (option-present-p "--unsafe")
      (format t "~&Using unsafe entry point~%")
      (setf entry-point "quilc::%entry-point"))
    (force-output)
    (unload-libraries)
    (sb-ext:save-lisp-and-die output-file
                              :compression #+sb-core-compression t
                              #-sb-core-compression nil
                              :save-runtime-options t
                              :executable t
                              :toplevel (make-toplevel-function entry-point))))
