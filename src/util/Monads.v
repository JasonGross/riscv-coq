Require Import Coq.Logic.FunctionalExtensionality.
Require Import Coq.Logic.PropExtensionality.
Require Import Coq.Lists.List.

Class Monad(M: Type -> Type) := mkMonad {
  Bind: forall {A B}, M A -> (A -> M B) -> M B;
  Return: forall {A}, A -> M A;

  left_identity: forall {A B} (a: A) (f: A -> M B),
    Bind (Return a) f = f a;
  right_identity: forall {A} (m: M A),
    Bind m Return = m;
  associativity: forall {A B C} (m: M A) (f: A -> M B) (g: B -> M C),
    Bind (Bind m f) g = Bind m (fun x => Bind (f x) g)
}.


Notation "x <- m1 ; m2" := (Bind m1 (fun x => m2))
  (right associativity, at level 60) : monad_scope.
Notation "m1 ;; m2" := (Bind m1 (fun _ => m2))
  (right associativity, at level 60) : monad_scope.

Open Scope monad_scope.

Ltac prove_monad_law :=
  repeat match goal with
         | |- _ => intro
         | |- _ => apply functional_extensionality
         | |- _ => apply propositional_extensionality; split; intros
         | H: exists x, _ |- _ => destruct H
         | H: _ /\ _ |- _ => destruct H
         | p: _ * _ |- _ => destruct p
         | |- context [ let (_, _) := ?p in _ ] => let E := fresh "E" in destruct p eqn: E
         | H: Some _ = Some _ |- _ => inversion H; clear H; subst
         | H: (_, _) = (_, _) |- _ => inversion H; clear H; subst
         | |- _ => discriminate
         | |- _ => progress subst
         | |- _ => solve [eauto 10]
         | H: _ \/ _ |- _ => destruct H
         | o: option _ |- _ => destruct o
         end.

Instance option_Monad: Monad option := {|
  Bind := fun {A B: Type} (o: option A) (f: A -> option B) => match o with
          | Some x => f x
          | None => None
          end;
  Return := fun {A: Type} (a: A) => Some a
|}.
all: prove_monad_law.
Defined.


Definition NonDet(A: Type): Type := A -> Prop.

Instance NonDet_Monad: Monad NonDet := {|
  Bind{A B}(m: NonDet A)(f: A -> NonDet B) :=
    fun (b: B) => exists a, m a /\ f a b;
  Return{A} := eq;
|}.
all: prove_monad_law.
Defined.


Definition State(S A: Type) := S -> (A * S).

Instance State_Monad(S: Type): Monad (State S) := {|
  Bind := fun {A B: Type} (m: State S A) (f: A -> State S B) =>
            fun (s: S) => let (a, s') := m s in f a s' ;
  Return := fun {A: Type} (a: A) =>
              fun (s: S) => (a, s)
|}.
all: prove_monad_law.
Defined.

Module StateM.
Definition get{S: Type}: State S S := fun (s: S) => (s, s).
Definition gets{S A: Type}(f: S -> A): State S A := fun (s: S) => (f s, s).
Definition put{S: Type}(s: S): State S unit := fun _ => (tt, s).
End StateM.


Definition OState(S A: Type) := S -> (option A) * S.

Instance OState_Monad(S: Type): Monad (OState S) := {|
  Bind := fun {A B: Type} (m: OState S A) (f: A -> OState S B) =>
            fun (s: S) => match m s with
            | (Some a, s') => f a s'
            | (None, s') => (None, s')
            end;
  Return := fun {A: Type} (a: A) =>
              fun (s: S) => (Some a, s)
|}.
all: prove_monad_law.
Defined.


(* option is for failure, Prop is for non-determinism.
   We can think of it as "S -> (option (A * S) -> Prop)", i.e. a function returning
   a unique set of all possible outcomes. *)
Definition OStateND(S A: Type) := S -> option (A * S) -> Prop.

Instance OStateND_Monad(S: Type): Monad (OStateND S) := {|
  Bind{A B}(m: OStateND S A)(f : A -> OStateND S B) :=
    fun (s : S) (obs: option (B * S)) =>
      (m s None /\ obs = None) \/
      (exists a s', m s (Some (a, s')) /\ f a s' obs);
  Return{A}(a : A) :=
    fun (s : S) (oas: option (A * S)) => oas = Some (a, s);
|}.
all: prove_monad_law.
Defined.
