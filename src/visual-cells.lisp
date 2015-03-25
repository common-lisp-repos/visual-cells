;; visual-cells.lisp
;; package
(require :cl-cairo2)
(defpackage :visual-cells
  (:use :common-lisp :cl-cairo2)
  (:export :fvs))
(in-package :visual-cells)

;;tool maccro to ignore stle warning of cffi
(defun ignore-warning (condition)
   (declare (ignore condition))
   (muffle-warning))
(defmacro igw (&rest forms)  
  `(handler-bind ((warning #'ignore-warning))
     ,@forms))

;; draw functions
(defun draw-text-node(x y name &key label )  
  (let* ((n-exts (igw (get-text-extents name)))
	 (n-width (text-width n-exts))
	 (n-height (text-height n-exts))
	 (n-x-offset (+ (text-x-bearing n-exts)  (/ n-width 2)))
	 (n-y-offset (+ (text-y-bearing n-exts) (/ n-height 2)))
	 (n-radius (/ (sqrt (+ (expt n-width 2) (expt n-height 2))) 1.8)))
    (move-to (- x n-x-offset) (- y n-y-offset))
    (show-text name)
    
    (new-path)
    (arc x y n-radius 0 (* 2.0 PI))
    (save)
    (set-line-width (* 4 (get-line-width)))
    (stroke)
    (restore)
    (when label
      (save)
      (set-font-size  (/ (trans-matrix-xx (igw (get-font-matrix))) 2))      
      (let* ((l-exts (igw (get-text-extents label)))
	     (l-width (text-width l-exts))
	     (l-x-offset (+ (text-x-bearing l-exts) (/ l-width 2)))
	     (l-y-offset (- (text-y-bearing l-exts) (* 7/5 n-radius))))
	(move-to (- x l-x-offset) (- y l-y-offset))
	(show-text label))
      (restore))    
    n-radius))

(defun draw-atom (x y obj)
  (let ((name (typecase obj
		(integer "In")
		(float "Fl")
		(number "Nu")
		(keyword "Ke")
		(symbol "Sy")
		(string "St")
		(array "Ar")
		(character "Ch")
		(t "T")))
	(label (format nil "~A" obj)))
    (draw-text-node x y name :label label)))

;;radius of Current Font
(defun get-font-radius () 
  (let* ((fm (igw (get-font-matrix)))
	 (xx (trans-matrix-xx fm))
	 (yy (trans-matrix-yy fm)))
    (/ (sqrt (+ (expt xx 2) (expt yy 2)))2.2)))

;;draw cons cell node
(defun draw-cons-node(x y)
  (let ((radius (get-font-radius)))
    (new-path)
    (arc x y radius 0 (*  PI 2))
    (save)
    (set-line-width (* 4 (get-line-width)))
    (stroke)
    (restore)
    (let ((h-radius (/ radius 2)))
      (arc-negative (+ x h-radius) y h-radius 0 PI)
      (arc (- x h-radius) y h-radius 0 PI))    
    (stroke)    
    (arc (- x (/ radius 2)) y (/ radius 8) 0 (* 2 PI))
    (close-path)
    (fill-path)
    (arc (+ x (/ radius 2)) y (/ radius 8) 0 (* 2 PI))
    (close-path)
    (fill-path)    
  radius))

;;angle of vector
(defun line-angle (dx dy)
  (cond ((zerop dx) (if (>= dy 0) (* 1/2 PI) (* -1/2 PI)))
	((> dx 0) (atan (/ dy dx)))
	(t (+ PI (atan (/ dy dx))))))

;;draw point
(defun draw-pointer (fx fy tx ty tr)
  (let* ((dx (- fx tx))
	 (dy (- fy ty))
	 (len (sqrt (+ (expt dx 2) (expt dy 2))))
	 (tpk (/ (* tr 6/5) len))
	 (tpx (+ tx (* tpk dx)))
	 (tpy (+ ty (* tpk dy)))
	 (tp-angle (line-angle dx dy)))
    (new-path)
    (move-to fx fy)
    (line-to tpx tpy)
    (save)
    (set-line-width (* 2 (get-line-width)))
    (stroke)
    (restore)
    (arc tx ty (* tr 6/5) (- tp-angle (/ PI 4)) (+ tp-angle (/ PI 4)))
    (stroke)))

;;reprenting space
(defstruct (cons-extents  (:conc-name cons-))
  (left 0)
  (right 0)
  (height 0))

;;get space of cons
(defun get-cons-extents (obj)
  (let ((exts (make-cons-extents)))
    (when (consp obj)
      (let* ((lc (car obj))
	     (rc (cdr obj))
	     (le (get-cons-extents lc))
	     (re (get-cons-extents rc)))
	(when (or lc rc)
	  (incf (cons-height exts) 1)
	  (incf (cons-height exts)
		(max (cons-height le)
		     (cons-height re)))
	  (when lc
	    (incf (cons-left exts) 1)
	    (incf (cons-left exts)
		  (cons-left le))
	    (incf (cons-left exts)
		  (cons-right le))
	  (when rc
	    (incf (cons-right exts) 1)
	    (incf (cons-right exts)
		  (cons-right re))
	    (incf (cons-right exts)
		  (cons-left re)))))))
    exts))

;;draw cons
(defun draw-cons (x y obj hgap vgap)
  (if (atom obj)
      (draw-atom x y obj)      
      (let* ((p-radius (draw-cons-node x y))
	     (p-left-x (- x (/ p-radius 2)))
	     (p-right-x (+ x (/ p-radius 2)))
	     (left-cell (car obj))
	     (right-cell (cdr obj))
	     (left-exts (get-cons-extents left-cell))
	     (right-exts (get-cons-extents right-cell)))
	(when left-cell
	  (let* ((left-x (- x
			    (* hgap (+ 1
					 (cons-right
					  left-exts)))))
		 (left-y (+ y vgap))
		 (left-radius (draw-cons left-x left-y left-cell hgap vgap)))
	    (draw-pointer p-left-x y left-x left-y left-radius)))
	(when right-cell
	  (let* ((right-x (+ x (* hgap
				  (max  1 (cons-left
					 right-exts)))))
		 (right-y (+ y vgap))
		 (right-radius (draw-cons right-x right-y right-cell hgap vgap)))
	    (draw-pointer p-right-x y right-x right-y right-radius)))
	p-radius)))

;;entry function
(defun fvs (obj fname &key
			(font-size 20)
			(line-width 0.5)
			(v-gap 60)
			(h-gap 25))
  (let* ((exts (get-cons-extents obj))
	 (width (* h-gap (+ 2 (cons-left exts) (cons-right exts))))
	 (height (* v-gap (+ 2 (cons-height exts))))
	 (x (* h-gap (+ 2 (cons-left exts))))
	 (y (* v-gap 1))
	 (surface (create-pdf-surface (concatenate 'string fname ".pdf")
				      width
				      height))
	 (*context* (create-context surface)))   
    (set-font-size font-size)
    (set-line-width line-width)
    (set-source-rgb 0.0 0.0 0.0)
    (paint)
    (set-source-rgb 0.1 0.8 0.2)
    (draw-cons x y obj h-gap v-gap)
    (surface-write-to-png surface (concatenate 'string fname ".png"))
    (destroy surface)
    (destroy *context*)))


