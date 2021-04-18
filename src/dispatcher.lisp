
(in-package :cl-gserver.dispatcher)

(shadowing-import '(mesgb:message-box/bt
                    act:actor))

(defun make-dispatcher (actor-context &key (num-workers 1))
  "Default constructor.
This creates a `shared-dispatcher` with `num-workers` number of workers.
Each worker is based on a `:pinned` actor meaning that it has its own thread.
Specify an `ac:actor-context` where actors needed in the dispatcher are created in."
  (make-instance 'shared-dispatcher
                 :num-workers num-workers
                 :context actor-context))

(defclass dispatcher-base ()
  ((context :initform nil
            :initarg :context))
  (:documentation
   "A `dispatcher` contains a pool of `actors` that operate as workers where work is dispatched to."))

;; ---------------------------------
;; Shared dispatcher
;; ---------------------------------

(defclass shared-dispatcher (dispatcher-base)
  ((router :initform (router:make-router :strategy :random)))
  (:documentation
   "A shared dispatcher.
Internally it uses a `router:router` to drive the `dispatch-worker`s.
The default strategy of choosing a worker is `:random`.

A `shared-dispatcher` is automatically setup by an `asys:actor-system`."))

(defmethod initialize-instance :after ((self shared-dispatcher) &key (num-workers 1))
  (with-slots (router context) self
    (loop :for n :from 1 :to num-workers
          :do (router:add-routee router (make-dispatcher-worker n context)))))

(defmethod print-object ((obj shared-dispatcher) stream)
  (print-unreadable-object (obj stream :type t)
    (with-slots (router) obj
      (format stream "workers: ~a, strategy: ~a"
              (length (router:routees router))
              (router:strategy-fun router)))))

(defmethod workers ((self shared-dispatcher))
  (with-slots (router) self
    (router:routees router)))

(defmethod shutdown ((self shared-dispatcher))
  (with-slots (router) self
    (router:stop router)))

(defmethod dispatch ((self shared-dispatcher) dispatch-exec-fun)
  (with-slots (router) self
    (router:ask-s router (cons :execute dispatch-exec-fun))))

(defmethod dispatch-async ((self shared-dispatcher) dispatch-exec-fun)
  (with-slots (router) self
    (router:tell router (cons :execute dispatch-exec-fun))))


;; ---------------------------------
;; the worker
;; ---------------------------------

(defclass dispatch-worker (actor) ()
  (:documentation
   "Specialized `actor` used as `worker` is the message `dispatcher`."))

(defun make-dispatcher-worker (num actor-context)
  "Constructor for creating a worker.
`num` only has the purpose to give the worker a name which includes a number."
  (ac:actor-of actor-context
    (lambda ()
      (act:make-actor #'receive
                      :type 'dispatch-worker
                      :name (utils:mkstr "dispatch-worker-" num)))
    :dispatch-type :pinned))

(defun receive (self message current-state)
  "The worker receive function."
  (assert (consp message) nil (format t "~a: Message must be a `cons'!" (act-cell:name self)))
  (case (car message)
    (:execute (cons (funcall (cdr message)) current-state))))
