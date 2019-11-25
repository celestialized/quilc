;;;; csd-tests.lisp
;;;;
;;;; Author: Juan M. Bello-Rivas

(in-package #:cl-quil-tests)

(defun m= (a b &key (test #'quil::double=))
  "Returns T if matrices A and B are sufficiently close, NIL otherwise. The TEST function determines the tolerance for comparison."
  (flet ((norm-vec-inf (matrix)
           (reduce #'max (magicl::matrix-data matrix) :key #'abs)))
    (funcall test 0.0d0 (norm-vec-inf (quil::m- a b)))))

(defparameter *csd-dim* 16 "Dimension of unitary matrices used for testing purposes.")

(deftest test-csd-2x1 ()
  (let* ((m *csd-dim*)
         (n (floor m 2))
         (a (magicl:random-unitary m))
         (a3 (magicl:slice a 0 n n m))
         (a4 (magicl:slice a n m n m))
         (id (magicl:make-identity-matrix n)))
    (multiple-value-bind (u1 u2 c s v2h)
        (quil::csd-2x1 a3 a4)
      (let ((u1h (magicl:conjugate-transpose u1))
            (u2h (magicl:conjugate-transpose u2))
            (v2 (magicl:conjugate-transpose v2h)))
        (is (m= id (quil::m* u1h u1)))
        (is (m= id (quil::m* u2h u2)))
        (is (m= id (quil::m* v2h v2)))
        (is (m= a3 (quil::m* u1 (quil::m- s) v2h)))
        (is (m= a4 (quil::m* u2 c v2h)))
        (is (m= id (quil::m+ (quil::m* c c) (quil::m* s s))))))))

(deftest test-csd-equipartition ()
  (let* ((m *csd-dim*)
         (n (/ m 2))
         (a (magicl:random-unitary m))
         (a1 (magicl:slice a 0 n 0 n))
         (a2 (magicl:slice a n m 0 n))
         (a3 (magicl:slice a 0 n n m))
         (a4 (magicl:slice a n m n m))
         (id (magicl:make-identity-matrix n)))
    (multiple-value-bind (u1 u2 v1h v2h theta)
        (quil::csd a n n)
      (let ((u1h (magicl:conjugate-transpose u1))
            (u2h (magicl:conjugate-transpose u2))
            (v1 (magicl:conjugate-transpose v1h))
            (v2 (magicl:conjugate-transpose v2h)))
        (is (m= id (quil::m* u1h u1)))
        (is (m= id (quil::m* u2h u2)))
        (is (m= id (quil::m* v1h v1)))
        (is (m= id (quil::m* v2h v2)))
        (multiple-value-bind (c s)
            (let ((c (magicl:make-zero-matrix n n))
                  (s (magicl:make-zero-matrix n n)))
              (dotimes (i n (values c s))
                (setf (magicl:ref c i i) (cos (nth i theta))
                      (magicl:ref s i i) (sin (nth i theta)))))
          (is (m= a1 (quil::m* u1 c v1h)))
          (is (m= a2 (quil::m* u2 s v1h)))
          (is (m= a3 (quil::m* u1 (quil::m- s) v2h)))
          (is (m= a4 (quil::m* u2 c v2h))))))))

(deftest test-csd-uneven-partition ()
  (let* ((m *csd-dim*)
         (n 1)
         (a (magicl:random-unitary m))
         (a1 (magicl:slice a 0 n 0 n))
         (a2 (magicl:slice a n m 0 n))
         (a3 (magicl:slice a 0 n n m))
         (a4 (magicl:slice a n m n m))
         (id (magicl:make-identity-matrix n)))
    (multiple-value-bind (u1 u2 v1h v2h theta)
        (quil::csd a n n)
      (let ((c (cos (first theta)))
            (s (sin (first theta)))
            (u1h (magicl:conjugate-transpose u1))
            (u2h (magicl:conjugate-transpose u2))
            (v1 (magicl:conjugate-transpose v1h))
            (v2 (magicl:conjugate-transpose v2h)))
        (is (m= id (quil::m* u1h u1)))
        (is (m= id (quil::m* u2h u2)))
        (is (m= id (quil::m* v1h v1)))
        (is (m= id (quil::m* v2h v2)))
        (is (m= a1 (magicl:scale c (quil::m* u1 v1h))))
        (let ((svec (let ((x (magicl:make-zero-matrix (1- m) 1)))
                      (setf (magicl:ref x (- m 2) 0) s)
                      x)))
          (is (m= a2 (quil::m* u2 svec v1h)))
          (is (m= a3 (quil::m* u1 (magicl:conjugate-transpose (quil::m- svec)) v2h))))
        (let ((cmat (let ((x (magicl:make-identity-matrix (1- m))))
                      (setf (magicl:ref x (- m 2) (- m 2)) c)
                      x)))
          (is (m= a4 (quil::m* u2 cmat v2h))))))))
