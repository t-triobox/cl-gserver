;; ----------------------------------------
;; Actor-Context implementation
;; ----------------------------------------

(in-package :cl-gserver.actor-context)
    
(defun get-shared-dispatcher (system)
  (getf (sys:dispatchers system) :shared))

(defun add-actor (context actor)
  (vector-push-extend actor (actors context))
  actor)

(defun message-box-for-dispatch-type (dispatch-type context)
  (case dispatch-type
    (:pinned (make-instance 'mesgb:message-box-bt))
    (otherwise (make-instance 'mesgb:message-box-dp
                              :dispatcher (get-shared-dispatcher (system context))
                              :max-queue-size 0))))

(defun make-actor (context create-fun dispatch-type)
  (let ((actor (funcall create-fun)))
    (when actor
      (setf (act-cell:msgbox actor) (message-box-for-dispatch-type dispatch-type context))
      (setf (act:context actor) (make-actor-context (system context))))
    actor))

(defmethod actor-of ((self actor-context) create-fun &key (dispatch-type :shared))
  (let ((created (make-actor self create-fun dispatch-type)))
    (when created
      (add-actor self created))))

(defmethod find-actors ((self actor-context) find-fun)
  (mapcan (lambda (x) (if (funcall find-fun x) (list x))) (all-actors self)))

(defmethod all-actors ((self actor-context))
  (coerce (actors self) 'list))

(defmethod shutdown ((self actor-context))
  (dolist (actor (all-actors self))
    (act-cell:stop actor)))
