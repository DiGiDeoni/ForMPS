!!  This module describes an object with three legs as used by MPS algorithms.
!!  One leg is "special", it is the physical leg of the tensor.
!!  In notation it is nice to have the spin as the first index, but in the implementation 
!!  it is the third, as it makes it better for performance

module MPSTensor_Class

  use ErrorHandling
  use Constants

  implicit none

  integer,parameter :: MAX_spin = 2, MAX_D = 100

!###############################
!#####  The class main object
!###############################
  type MPSTensor
     private
     integer spin_,DLeft_,DRight_ 
     logical :: initialized_=.false.
     complex(8) data_(MAX_D,MAX_D,MAX_spin) !!$TODO: Now uses fixed max dimensions and internal variables, change to allocatable
   contains
     procedure delete => delete_MPSTensor
     procedure print => print_MPSTensor
     procedure DRight => DRight_MPSTensor
     procedure DLeft => DLeft_MPSTensor
     procedure Spin => Spin_MPSTensor
     procedure LCanonize => Left_Canonize_MPSTensor
!     procedure RCanonize => Right_Canonize_MPSTensor !!$TODO: Right canonization
  end type MPSTensor

!###############################
!#####  Operators and methods
!###############################
  interface new_MPSTensor
     module procedure new_MPSTensor_Random,new_MPSTensor_fromMPSTensor,new_MPSTensor_withData,new_MPSTensor_withConstant
  end interface

  interface operator (*)
     module procedure Integer_times_MPSTensor,Real_times_MPSTensor,Complex_times_MPSTensor,Real8_times_MPSTensor, &
          & Complex8_times_MPSTensor,Matrix_times_MPSTensor
  end interface

  interface operator (.diff.)
     module procedure Difference_btw_MPSTensors
  end interface

  interface operator (.equaldims.)
     module procedure  MPSTensors_are_of_equal_Shape
  end interface

!######################################################################################
!######################################################################################
!######################################################################################
!######################################################################################
!######################################################################################
!######################################################################################
!######################################################################################

 contains

!######################################################################################
!#####                           Creation operators
!######################################################################################
   function new_MPSTensor_Random (spin,DLeft,DRight) result (this)
     integer,intent(in) :: spin,DLeft,DRight
     type(MPSTensor) :: this
     integer :: n,alpha,beta
     integer,save :: iseed = 101

     if(spin.gt.MAX_spin.or.DLeft.gt.MAX_D.or.DRight.gt.MAX_D) then
        call ThrowException('new_MPSTensor_Random','spin or bond dimension larger than maximum',NoErrorCode,CriticalError)
        return
     endif
     if(spin.lt.1.or.DLeft.lt.1.or.DRight.lt.1) then
        call ThrowException('new_MPSTensor_Random','spin or bond dimension smaller than 1',NoErrorCode,CriticalError)
        return
     endif

     !initialize internal variables
     this%spin_=spin
     this%DLeft_=DLeft
     this%DRight_=DRight
     !initialize data
     this%data_=zero
     do n=1,spin
        do beta=1,DRight
           do alpha=1,DLeft
              this%data_(alpha,beta,n)=ran(iseed)+II*ran(iseed)
           enddo
        enddo
     enddo
     !Flip flag
     this%initialized_=.true.

   end function new_MPSTensor_Random

!##################################################################
   function new_MPSTensor_withData (spin,DLeft,DRight,originalData) result (this)
     integer,intent(in) :: spin,DLeft,DRight
     complex(8),intent(in) :: originalData(:,:,:)
     type(MPSTensor) this
     integer :: n,alpha,beta

     if(spin.gt.MAX_spin.or.DLeft.gt.MAX_D.or.DRight.gt.MAX_D) then
        call ThrowException('new_MPSTensor_withData','spin or bond dimension larger than maximum',NoErrorCode,CriticalError)
        return
     endif
     if(spin.lt.1.or.DLeft.lt.1.or.DRight.lt.1) then
        call ThrowException('new_MPSTensor_withData','spin or bond dimension smaller than 1',NoErrorCode,CriticalError)
        return
     endif

     this%spin_=spin
     this%DLeft_=DLeft
     this%DRight_=DRight
     this%data_=zero
     do n=1,spin
        do beta=1,DRight
           do alpha=1,DLeft
              this%data_(alpha,beta,n)=originalData(alpha,beta,n)
           enddo
        enddo
     enddo
     this%initialized_=.true.

   end function new_MPSTensor_withData

!##################################################################
   function new_MPSTensor_withConstant (spin,DLeft,DRight,constant) result (this)
     integer,intent(in) :: spin,DLeft,DRight
     complex(8),intent(in) :: constant
     type(MPSTensor) this
     integer :: n,alpha,beta

     if(spin.gt.MAX_spin.or.DLeft.gt.MAX_D.or.DRight.gt.MAX_D) then
        call ThrowException('new_MPSTensor_withData','spin or bond dimension larger than maximum',NoErrorCode,CriticalError)
        return
     endif
     if(spin.lt.1.or.DLeft.lt.1.or.DRight.lt.1) then
        call ThrowException('new_MPSTensor_withData','spin or bond dimension smaller than 1',NoErrorCode,CriticalError)
        return
     endif

     this%spin_=spin
     this%DLeft_=DLeft
     this%DRight_=DRight
     this%data_=zero
     do n=1,spin
        do beta=1,DRight
           do alpha=1,DLeft
              this%data_(alpha,beta,n)=constant
           enddo
        enddo
     enddo
     this%initialized_=.true.

   end function new_MPSTensor_withConstant

!##################################################################
   function new_MPSTensor_fromMPSTensor (tensor) result (this)
     type(MPSTensor),intent(in) :: tensor
     type(MPSTensor) this

     if(.not.tensor%initialized_) then
        call ThrowException('new_MPSTensor_fromMPSTensor','Original tensor not initialized',NoErrorCode,CriticalError)
        return
     endif

     this%spin_=tensor%spin_
     this%DLeft_=tensor%DLeft_
     this%DRight_=tensor%DRight_
     this%data_=zero
     this%data_=tensor%data_
     this%initialized_=.true.

   end function new_MPSTensor_fromMPSTensor


!######################################    delete
   integer function delete_MPSTensor (this) result(error)
     class(MPSTensor),intent(INOUT) :: this

     error=Warning

     if(.not.this%initialized_) then
        call ThrowException('delete_MPSTensor','Trying to delete an uninitialized tensor',NoErrorCode,error)
        return
     endif
     
     !Erase info
     this%spin_=0
     this%DLeft_=0
     this%DRight_=0
     !Erase data
     this%data_=zero
     !Flip flag
     this%initialized_=.false.     

     error=Normal

   end function delete_MPSTensor
!##################################################################

!######################################     print
   integer function Print_MPSTensor(this) result(error)
     class(MPSTensor),intent(IN) :: this
     integer i,j,k

     error = Warning

     if(.not.(this%initialized_)) then
        call ThrowException('PrintMPSTensor','Tensor not initialized',NoErrorCode,error)
        return
     endif

     do i=1,this%spin_
        print *,'State :',i
        do j=1,this%DLeft_
           print *,(this%data_(j,k,i),k=1,this%DRight_)
        enddo
     enddo

     error=Normal

   end function Print_MPSTensor
!##################################################################   

!##################################################################
!###########       Accessor methods
!##################################################################
   integer function Spin_MPSTensor(this) result(s)
     class(MPSTensor),intent(IN) :: this
 
    if(.not.(this%initialized_)) then
        call ThrowException('Spin','Tensor not initialized',NoErrorCode,Warning)
        return
     else
        s=this%spin_
     endif

   end function Spin_MPSTensor
!##################################################################

   integer function DLeft_MPSTensor(this) result(DL)
     class(MPSTensor),intent(IN) :: this

     if(.not.(this%initialized_)) then
        call ThrowException('DLeft','Tensor not initialized',NoErrorCode,Warning)
        return
     else
        DL=this%DLeft_
     endif

   end function DLeft_MPSTensor
!##################################################################
   integer function DRight_MPSTensor(this) result(DR)

     class(MPSTensor),intent(IN) :: this

     if(.not.(this%initialized_)) then
        call ThrowException('DRight','Tensor not initialized',NoErrorCode,Warning)
        return
     else
        DR=this%DRight_
     endif

   end function DRight_MPSTensor

!##################################################################
!#######################        Products by things
!##################################################################
   function Integer_times_MPSTensor(constant, tensor) result(this)
     integer,intent(IN) :: constant
     type(MPSTensor),intent(IN) :: tensor
     type(MPSTensor) this

     if(tensor%initialized_) then
        this = new_MPSTensor(tensor%spin_,tensor%DRight_,tensor%DLeft_,constant*tensor%data_)
        return 
     else
        call ThrowException('Integer_times_MPSTensor','Tensor not initialized',NoErrorCode,CriticalError)
        return
     endif

   end function Integer_times_MPSTensor

!##################################################################
   function Real_times_MPSTensor(constant, tensor) result(this)
     real,intent(IN) :: constant
     type(MPSTensor),intent(IN) :: tensor
     type(MPSTensor) this

     if(tensor%initialized_) then
        this = new_MPSTensor(tensor%spin_,tensor%DRight_,tensor%DLeft_,constant*tensor%data_)
        return 
     else
        call ThrowException('Real_times_MPSTensor','Tensor not initialized',NoErrorCode,CriticalError)
        return
     endif

   end function Real_times_MPSTensor

!##################################################################
   function Real8_times_MPSTensor(constant, tensor) result(this)
     real(8),intent(IN) :: constant
     type(MPSTensor),intent(IN) :: tensor
     type(MPSTensor) this

     if(tensor%initialized_) then
        this = new_MPSTensor(tensor%spin_,tensor%DRight_,tensor%DLeft_,constant*tensor%data_)
        return 
     else
        call ThrowException('Real8_times_MPSTensor','Tensor not initialized',NoErrorCode,CriticalError)
        return
     endif

   end function Real8_times_MPSTensor

!##################################################################
   function Complex_times_MPSTensor(constant, tensor) result(this)
     complex,intent(IN) :: constant
     type(MPSTensor),intent(IN) :: tensor
     type(MPSTensor) this

     if(tensor%initialized_) then
        this = new_MPSTensor(tensor%spin_,tensor%DRight_,tensor%DLeft_,constant*tensor%data_)
        return 
     else
        call ThrowException('Complex_times_MPSTensor','Tensor not initialized',NoErrorCode,CriticalError)
        return
     endif

   end function Complex_times_MPSTensor

!##################################################################
   function Complex8_times_MPSTensor(constant, tensor) result(this)
     complex(8),intent(IN) :: constant
     type(MPSTensor),intent(IN) :: tensor
     type(MPSTensor) this

     if(tensor%initialized_) then
        this = new_MPSTensor(tensor%spin_,tensor%DRight_,tensor%DLeft_,constant*tensor%data_)
        return 
     else
        call ThrowException('Complex8_times_MPSTensor','Tensor not initialized',NoErrorCode,CriticalError)
        return
     endif

   end function Complex8_times_MPSTensor


!##################################################################
!###  IMPORTANT NOTE ON THE INTERFACE OF Matrix_times_MPSTensor:
!###  One of the arguments must be a "matrix", i.e. a MPSTensor with spin=MatrixSpin=1
!###  The order of the arguments is VERY important
!###  If the first argument is a matrix, then the result is matrix.tensor
!###  otherwise the result is tensor.matrix
!###
   function Matrix_times_MPSTensor(tensorA, tensorB) result(this)
     type(MPSTensor),intent(IN) :: tensorA,tensorB
     type(MPSTensor) this
     integer :: s

     if(tensorA%initialized_.and.tensorB%initialized_) then
        if(tensorA%DRight_.eq.tensorB%DLeft_) then
           !The trick of using a tensor as a matrix is used here:
           if (tensorA%spin_.eq.MatrixSpin) then
              this = new_MPSTensor(tensorB%spin_,tensorA%DLeft_,tensorB%DRight_,zero)
              do s=1,tensorB%spin_
                 call mymatmul(tensorA%data_(:,:,MatrixSpin),tensorB%data_(:,:,s),this%data_(:,:,s), &
                      & tensorA%DLeft_,tensorB%DLeft_,tensorB%DRight_,'N')
              enddo
           else if (tensorB%spin_.eq.MatrixSpin) then
              this = new_MPSTensor(tensorA%spin_,tensorA%DLeft_,tensorB%DRight_,zero)
              do s=1,tensorA%spin_
                 call mymatmul(tensorA%data_(:,:,s),tensorB%data_(:,:,MatrixSpin),this%data_(:,:,s), &
                      & tensorA%DLeft_,tensorB%DLeft_,tensorB%DRight_,'N')
              enddo              
           else
              call ThrowException('Matrix_times_MPSTensor','One of the arguments must be a *matrix* (MPSTensor with spin 1)',NoErrorCode,CriticalError)
           endif
        else
           call ThrowException('Matrix_times_MPSTensor','Dimensions of the tensors do not match',NoErrorCode,CriticalError)
        endif
     else
        call ThrowException('Matrix_times_MPSTensor','Tensor not initialized',NoErrorCode,CriticalError)
     endif
     return
   end function Matrix_times_MPSTensor

!##################################################################
!##################################################################
!##################################################################
!##################################################################

   real function Difference_btw_MPSTensors(tensor1, tensor2) result(diff)
     type(MPSTensor),intent(IN) :: tensor1,tensor2
     integer :: n,alpha,beta
     
     diff=0.0d0
     if(tensor1%initialized_.and.tensor2%initialized_) then
        if(tensor1.equaldims.tensor2) then
           do n=1,tensor1%spin_
              do beta=1,tensor1%DRight_
                 do alpha=1,tensor1%DLeft_
                    diff=diff+abs(tensor1%data_(alpha,beta,n)-tensor2%data_(alpha,beta,n))
                 enddo
              enddo
           enddo
        else
           call ThrowException('Difference_btw_MPSTensors','Tensors of different shape',NoErrorCode,CriticalError)
        endif
        return 
     else
        call ThrowException('Difference_btw_MPSTensors','Tensor not initialized',NoErrorCode,CriticalError)
        return
     endif     

   end function Difference_btw_MPSTensors

!##################################################################

   logical function MPSTensors_are_of_equal_Shape(tensor1,tensor2) result(equals)
     type(MPSTensor),intent(IN) :: tensor1,tensor2

     if(tensor1%initialized_.and.tensor2%initialized_) then
        equals=(tensor1%spin_.eq.tensor2%spin_).and.(tensor1%DLeft_.eq.tensor2%DLeft_).and.(tensor1%DRight_.eq.tensor2%DRight_)
        return 
     else
        call ThrowException('MPSTensors_are_of_equal_Shape','Tensors not initialized',NoErrorCode,CriticalError)
        return
     endif     

   end function MPSTensors_are_of_equal_Shape

!#######################################################################################
!#######################################################################################
! This are very important functions as most of the algorithm time is spent updating the
! matrices using this Left and Right products with tensors
! They are also used heavily for computing expectation values, so optimization here might be key
! Convention: 
!              L(betaR,alphaR) = \sum_i B_i^\dagger . L_in A_i
!                              = \sum_i \sum_betaL \sum_alphaL  B^*_{i,betaR,betaL} Lin_{betaL,alphaL} A_{i,alphaL,alphaR)
!
!              R(alphaL,betaL) = \sum_i A_i . RL_in . B_i^\dagger
!                              = \sum_i \sum_alphaR \sum_betaR A_{i,alphaL,alphaR) Rin_{alphaR,betaR} B^*_{i,betaR,betaL} 
!
!#######################################################################################
!#######################################################################################

   function MPS_Left_Product(TensorA,TensorB,matrixin) result(matrixout)
     type(MPSTensor),intent(IN) :: TensorA,TensorB
     type(MPSTensor) :: matrixout
     type(MPSTensor),intent(IN),optional :: matrixin
     type(MPSTensor) :: TempMatrix,L_in_matrix
     integer :: s,i,k,j,l
     complex(8) :: TEMP
     
     if((.not.tensorA%initialized_).and.(.not.tensorB%initialized_)) then
        call ThrowException('MPSLeftProduct','Tensors not initialized',NoErrorCode,CriticalError)
        return
     endif     
     if (TensorA%Spin_.ne.TensorB%spin_) then
        call ThrowException('MPSLeftProduct','Tensors have different spin',NoErrorCode,CriticalError)
        return
     endif
     if (present(matrixin)) then
        if(matrixin%initialized_) then
           L_in_matrix=new_MPSTensor(matrixin)
        else
           call ThrowException('MPSLeftProduct','Matrix is not initialized',NoErrorCode,CriticalError)
           return           
        endif
     else
        L_in_matrix=new_MPSTensor(MatrixSpin,TensorB%DLeft_,TensorA%DLeft_,one)
     endif

     matrixout=new_MPSTensor(MatrixSpin, TensorB%DRight_,TensorA%DRight_, zero)
     TempMatrix=new_MPSTensor(MatrixSpin,TensorB%DLeft_ ,TensorA%DRight_, zero)

     !The multiplications are done by hand because I could not get ZGEMM to work properly
     do s=1,TensorA%Spin_
        Tempmatrix%data_=0.0d0        
        call mymatmul(L_in_matrix%data_(:,:,MatrixSpin),TensorA%data_(:,:,s),Tempmatrix%data_(:,:,MatrixSpin), &
             & TensorB%DLeft_,TensorA%DLeft_,TensorA%DRight_,'N')
        call mymatmul(TensorB%data_(:,:,s),Tempmatrix%data_(:,:,MatrixSpin), MatrixOut%data_(:,:,MatrixSpin), &
             & TensorB%DRight_,TensorB%DLeft_,TensorA%DRight_,'A')
    enddo
    return 
  end function MPS_Left_Product

!##################################################################
!##################################################################

  function MPS_Right_Product(TensorA,TensorB,matrixin) result(matrixout)
    type(MPSTensor),intent(IN) :: TensorA,TensorB
    type(MPSTensor) :: matrixout
    type(MPSTensor),intent(IN),optional :: matrixin
    type(MPSTensor) :: TempMatrix,R_in_matrix
    integer :: s,i,k,j,l
    complex(8) :: TEMP
    
    if((.not.tensorA%initialized_).and.(.not.tensorB%initialized_)) then
       call ThrowException('MPSRightProduct','Tensors not initialized',NoErrorCode,CriticalError)
       return
    endif
    if (TensorA%Spin_.ne.TensorB%spin_) then
       call ThrowException('MPSRightProduct','Tensors have different spin',NoErrorCode,CriticalError)
       return
    endif
    
    matrixout=new_MPSTensor(MatrixSpin, TensorA%DLeft_,TensorB%DLeft_, zero)
    TempMatrix=new_MPSTensor(MatrixSpin,TensorA%DLeft_ ,TensorB%DRight_, zero)
    
    if (present(matrixin)) then
       if(matrixin%initialized_) then
          R_in_matrix=new_MPSTensor(matrixin)
       else
          call ThrowException('MPSRightProduct','Matrix is not initialized',NoErrorCode,CriticalError)
          return           
       endif
    else
       R_in_matrix=new_MPSTensor(MatrixSpin,TensorA%DRight_,TensorB%DRight_,one)
    endif
    
    !The multiplications are done by hand because I could not get ZGEMM to work properly
    do s=1,TensorA%Spin_
       Tempmatrix%data_=0.0d0  
       call mymatmul(TensorA%data_(:,:,s),R_in_matrix%data_(:,:,MatrixSpin),Tempmatrix%data_(:,:,MatrixSpin), &
            & TensorA%DLeft_,TensorA%DRight_,TensorB%DRight_,'N')
       call mymatmul(Tempmatrix%data_(:,:,MatrixSpin),TensorB%data_(:,:,s),MatrixOut%data_(:,:,MatrixSpin), &
            & TensorA%DLeft_,TensorB%DRight_,TensorB%DLeft_,'B')
    enddo
    return 
  end function MPS_Right_Product
  

!##################################################################
!##################################################################
! Site Canonization -- Returns the matrix that needs to be multiplied
! to the adjacent site
!##################################################################
!##################################################################

  function Left_Canonize_MPSTensor(this) result(matrix)
    class(MPSTensor),intent(INOUT) :: this
    type(MPSTensor) :: matrix
    complex(8), allocatable :: U(:,:),vTransposed(:,:),collapsedTensor(:,:)
    real(8),allocatable :: Sigma(:)
    integer :: Spin,LeftBond,RightBond
    integer :: newLeftBond,newRightBond
    integer :: jj,kk

    if(.not.this%initialized_) then
       call ThrowException('Left_Canonize_MPSTensor','Tensor not initialized',NoErrorCode,CriticalError)
       return
    endif

    Spin=this%spin_
    LeftBond=this%DLeft_
    RightBond=this%DRight_

    allocate(collapsedTensor(Spin*LeftBond,RightBond))
    allocate(U(Spin*LeftBond,Spin*LeftBond))
    allocate(Sigma(Min(Spin*LeftBond,RightBond)))
    allocate(vTransposed(RightBond,RightBond))

    call CollapseSpinWithBond(this,collapsedTensor,FirstDimension)
    if (WasThereError()) then
       call ThrowException('Left_Canonize_MPSTensor','Could not collapse the tensor',NoErrorCode,CriticalError)
       return
    endif

do jj=1,Spin*LeftBond
do kk=1,RightBond
    print *,jj,kk,CollapsedTensor(jj,kk)
enddo
enddo

    if(Spin*LeftBond.gt.MAX_D) then
       call ThrowException('Left_Canonize_MPSTensor','Working dimension larger than Maximum',NoErrorCode,CriticalError)
       return
    endif

    kk= SingularValueDecomposition(CollapsedTensor,U,Sigma,vTransposed)
    print *,'Output of SVD:',kk

    newLeftBond=LeftBond
    newRightBond=Min(Spin*LeftBond,RightBond)

    print *,'U'
    print *,U

    print *,'Sigma'
    print *,Sigma

    print *,'V'
    print *,vTransposed

!    this=(Partition[u, {newLeftBond, newRightBond}] [[All, 1]])
    call SplitSpinFromBond(U,this,FirstDimension,newLeftBond,newRightBond)
    if (WasThereError()) then
       call ThrowException('Left_Canonize_MPSTensor','Could not split the matrix',NoErrorCode,CriticalError)
       return
    endif

    !matrix is Sigma*V^\dagger and reshaped to fit the product with the tensor on the right
    matrix=new_MPSTensor(MatrixSpin,newRightBond,RightBond, & 
         & reshape(vecmul(Sigma,conjg(vTransposed)) , [newRightBond,RightBond,MatrixSpin], &
         & Pad= [ (zero, kk=1,newRightBond*RightBond*MatrixSpin) ]   ) )  !! Pad with zeros at the end

  end function Left_Canonize_MPSTensor
  

!!$ Mathematica code for canonization
!!$
!!$ Options[MPSCanonizeSite] = {Direction -> "Right", UseMatrix -> True};
!!$ SetAttributes[MPSCanonizeSite, HoldAll];
!!$ MPSCanonizeSite[tensor_, matrix_, OptionsPattern[]] := 
!!$  Module[{sense = OptionValue[Direction], 
!!$    usematrix = OptionValue[UseMatrix], 
!!$    numTensors, \[Chi]L, \[Chi]R, \[Chi], u, v, t, newTensor},(* 
!!$   Start by multiplying the tensor with the matrix from the previous site *)
!!$   If[sense == "Right",
!!$    If[usematrix, newTensor = tensor.matrix, newTensor = tensor];
!!$    {\[Chi]L, \[Chi]R} = Dimensions[newTensor[[1]]];
!!$    \[Chi] = Max[\[Chi]L, \[Chi]R];
!!$    (* SVD of the new tensor, putting [chiL, spin*
!!$    chiR] *)
!!$    {u, v, t} = 
!!$     SingularValueDecomposition[Flatten[newTensor, {{2}, {1, 3}}]];
!!$    (* Prepare new right matrix *)
!!$    
!!$    matrix = 
!!$     PadRight[
!!$      u.v, {Min[\[Chi], \[Chi]L], Min[\[Chi], Length[t], \[Chi]L]}];
!!$    (* Form the new tensor with the first row of t^
!!$    dagger *)
!!$    (Partition[
!!$       ConjugateTranspose[
!!$        t], {Min[\[Chi], Length[t], \[Chi]L], \[Chi]R}][[1, All]])
!!$    , (* LEFT CANONIZATION *)
!!$    If[usematrix, newTensor = matrix.# & /@ tensor, 
!!$     newTensor = tensor];
!!$    {\[Chi]L, \[Chi]R} = Dimensions[newTensor[[1]]];
!!$    \[Chi] = Max[\[Chi]L, \[Chi]R];
!!$    (* SVD of the new tensor, putting [chiL*spin, 
!!$    chiR] *)
!!$    {u, v, t} = 
!!$     SingularValueDecomposition[Flatten[newTensor, {{1, 2}, {3}}]];
!!$    (* Prepare new right matrix *)
!!$    
!!$    matrix = 
!!$     PadRight[
!!$      v.ConjugateTranspose[t], {Min[\[Chi], Length[u], \[Chi]R], 
!!$       Min[\[Chi], \[Chi]R]}];
!!$    (* Form the new tensor with the first column of u *)
!!$    \
!!$    (Partition[u, {\[Chi]L, Min[\[Chi], Length[u], \[Chi]R]}][[All, 1]])
!!$    ]
!!$   ];



!#######################################################################################
!#######################################################################################
! 
!                                    HELPER CODE
!
!#######################################################################################
!#######################################################################################

  subroutine CollapseSpinWithBond(this,collapsed,whichDimension)
    Type(MPSTensor),intent(IN) :: this
    complex(8),intent(OUT) :: collapsed(:,:)
    integer,intent(IN) :: whichDimension
    integer :: s,alpha,beta,leftIndex,rightIndex,leftStep,rightStep,leftDimension,rightDimension

    if(.not.this%initialized_) then
       call ThrowException('CollapseSpinWithBond','Tensor not initialized',NoErrorCode,CriticalError)
       return
    endif

    if (whichDimension.eq.FirstDimension) then
       leftStep=this%DLeft_
       rightStep=0
       leftDimension=(this%spin_*this%DLeft_)
       rightDimension=(this%DRight_)
    else if (whichDimension.eq.SecondDimension) then
       leftStep=0
       rightStep=this%DRight_
       leftDimension=(this%DLeft_)
       rightDimension=(this%spin_*this%DRight_)
    else
       call ThrowException('CollapseSpinWithBond','Wrong Dimension parameter',whichDimension,CriticalError)
       return
    endif
    if ((size(collapsed,1).ne.leftDimension).and.(size(collapsed,2).ne.rightDimension)) then
       call ThrowException('CollapseSpinWithBond','Matrix for collapsed tensor does not have right dimensions',whichDimension,CriticalError)
       return
    endif

    !This always puts the spin before the bond dimension,
    !      [(s,alpha),(beta)]   or  [(alpha),(s,beta)]
    do s=1,this%Spin_
       do beta=1,this%DRight_
          rightIndex=beta+(s-1)*rightStep
          do alpha=1,this%DLeft_
             leftIndex=alpha+(s-1)*leftStep
             collapsed(leftIndex,rightIndex)=this%data_(alpha,beta,s)
          enddo
       enddo
    enddo
             
  end subroutine CollapseSpinWithBond


!#######################################################################################


  subroutine SplitSpinFromBond(matrix,tensor,whichDimension,LeftBond,RightBond)
    complex(8),intent(IN) :: matrix(:,:)
    type(MPSTensor),intent(INOUT) :: tensor
    integer :: whichDimension,LeftBond,RightBond
    integer :: alpha,beta,s,spin
    integer :: leftIndex,rightIndex,leftStep,rightStep,leftDimension,rightDimension

    if(.not.tensor%initialized_) then
       call ThrowException('SplitSpinFromBond','Tensor not initialized',NoErrorCode,CriticalError)
       return
    endif
    
    spin=tensor%spin_
    if (whichDimension.eq.FirstDimension) then
       leftStep=LeftBond
       rightStep=0
       leftDimension=Spin*LeftBond
       rightDimension=RightBond
    else if (whichDimension.eq.SecondDimension) then
       leftStep=0
       rightStep=RightBond
       leftDimension=LeftBond
       rightDimension=Spin*RightBond
    else
       call ThrowException('CollapseSpinWithBond','Wrong Dimension parameter',whichDimension,CriticalError)
       return
    endif
    if ((size(matrix,1).lt.leftDimension).and.(size(matrix,2).lt.rightDimension)) then
       call ThrowException('SplitSpinFromBond','Matrix to split does not have right dimensions',whichDimension,CriticalError)
       return
    endif

    !This is the best way I found to zero out the tensor
    tensor=new_MPSTensor(Spin,LeftBond,RightBond,zero)
    do s=1,Spin
       do beta=1,RightBond
          rightIndex=beta+(s-1)*rightStep
          do alpha=1,LeftBond
             leftIndex=alpha+(s-1)*leftStep
             tensor%data_(alpha,beta,s)=matrix(leftIndex,rightIndex)
          enddo
       enddo
    enddo
            
  end subroutine SplitSpinFromBond




   subroutine mymatmul(A,B,C,indexL,indexC,indexR,mode)
     complex(8) :: A(:,:),B(:,:),C(:,:)
     integer :: indexL,indexC,indexR
     character*1 :: mode
     integer :: I,J,K,L
     complex(8) TEMP
     ! mode = 'N' is normal multiplication C = A * B + C
     ! mode = 'A' is with A dagged, C = A^+ * B + C
     ! mode = 'B' is with B dagged, C = A * B^+ + C
     if (mode.eq.'N'.or.mode.eq.'n') then
        !C = A * B + C
        DO J = 1,indexR
           DO L = 1,indexC
              IF (B(L,J).NE.ZERO) THEN
                 TEMP = B(L,J)
                 DO I = 1,indexL
                    C(I,J) = C(I,J) + A(I,L)*TEMP
                 enddo
              END IF
           enddo
        enddo
     else if (mode.eq.'A'.or.mode.eq.'a') then
        ! C = A^+ * B + C
        DO J = 1, indexR
           DO I = 1,indexL
              TEMP = ZERO
              DO L = 1,indexC
                 TEMP = TEMP + DCONJG(A(L,I))*B(L,J)
              enddo
             C(I,J) = TEMP + C(I,J)
           enddo
        enddo
     else if (mode.eq.'B'.or.mode.eq.'b') then
        ! C = A * B^+ + C
        DO J = 1,indexR
           DO L = 1,indexC
              IF (B(J,L).NE.ZERO) THEN
                 TEMP = DCONJG(B(J,L))
                 DO I = 1,indexL
                    C(I,J) = C(I,J) + A(I,L)*TEMP
                 enddo
              END IF
           enddo
        enddo

     endif
   end subroutine mymatmul

   function vecmul(vector,matrix) result(this)
     real(8),intent(IN) :: vector(:)
     complex(8),intent(IN) :: matrix(:,:)
     complex(8) :: this(size(matrix,1),size(matrix,2))
     integer :: LengthOfVector,LeftDimension,RightDimension
     integer :: i,j

     LengthOfVector=size(vector,1)
     LeftDimension=size(matrix,1)
     RightDimension=size(matrix,2)

     this=zero
     do i=1,min(LeftDimension,LengthOfVector)
        this(i,:)=vector(i)*matrix(i,:)
     enddo
    
   end function vecmul

   !Simplified interface for LAPACK's ZGESDD routine
   integer function SingularValueDecomposition(matrix,U,Sigma,vTransposed) result(ErrorCode)
     complex(8),intent(IN) :: matrix(:,:)
     complex(8),intent(OUT) :: U(:,:),vTransposed(:,:)
     real(8),intent(OUT) :: Sigma(:)
     integer :: LeftDimension,RightDimension
     !Lapack ugly variables
     integer :: Lwork,LRWork,LIWork,info
     complex(8),allocatable :: Work(:)
     real(8),allocatable :: RWork(:)
     integer(8),allocatable :: IWork(:)
     character,parameter :: Jobz='S' !Always get the minimum only, hopefully the rest of the matrix is zeroed out

     LeftDimension=size(matrix,1); RightDimension=size(matrix,2)

     !Checks
     if( (size(U,1).ne.LeftDimension).or.(size(U,2).ne.LeftDimension).or. &
          & (size(vTransposed,1).ne.RightDimension).or.(size(vTransposed,2).ne.RightDimension).or. &
          & (size(Sigma).ne.Min(LeftDimension,RightDimension)) ) then
        call ThrowException('SingularValueDecomposition','Dimensions of matrices do not match',ErrorCode,CriticalError)
        return
     endif        

     !Recommended values of memory allocation from LAPACK documentation
     LWork=(Min(LeftDimension,RightDimension)*(Min(LeftDimension,RightDimension)+2)+Max(LeftDimension,RightDimension))
     LRWork=5*Min(LeftDimension,RightDimension)*(Min(LeftDimension,RightDimension)+1)
     LIWork=8*Min(LeftDimension,RightDimension)

     allocate(Work(LWork),RWork(LRWork),IWork(LIWork),STAT=ErrorCode)
     If (ErrorCode.ne.Normal) then
        call ThrowException('SingularValueDecomposition','Could not allocate memory',ErrorCode,CriticalError)
        return
     endif
     !For some reason I need to call LAPACK with LWork=-1 first
     !And find out the optimum work storage, otherwise it returns an error
     LWork=-1
     call ZGESDD(JOBZ, LeftDimension, RightDimension, matrix, LeftDimension, Sigma, U, LeftDimension, vTransposed, RightDimension,WORK,LWORK,RWORK,IWORK,ErrorCode )
     If (ErrorCode.ne.Normal) then
        call ThrowException('SingularValueDecomposition','Lapack returned error in ZGESDD',ErrorCode,CriticalError)
        return
     endif
     !And now call with right value of LWork
     LWork=Max(LWork,Int(Work(1)))
     deallocate(Work)
     Allocate(Work(LWork))
     call ZGESDD(JOBZ, LeftDimension, RightDimension, matrix, LeftDimension, Sigma, U, LeftDimension, vTransposed, RightDimension,WORK,LWORK,RWORK,IWORK,ErrorCode )
     If (ErrorCode.ne.Normal) then
        call ThrowException('SingularValueDecomposition','Lapack returned error in ZGESDD',ErrorCode,CriticalError)
        return
     endif

     !Clean up
     deallocate(Work,RWork,IWork,STAT=ErrorCode)
     If (ErrorCode.ne.Normal) then
        call ThrowException('SingularValueDecomposition','Problems in deallocation',ErrorCode,CriticalError)
        return
     endif

     ErrorCode=Normal
     
   end function SingularValueDecomposition
     
   real function Difference_btw_Matrices(matrix1, matrix2) result(diff)
     complex(8) :: matrix1(:,:),matrix2(:,:)
     integer :: n,m,alpha,beta

     alpha=size(matrix1,1)
     beta=size(matrix1,2)
     diff=0.0d0
     if(alpha.eq.size(matrix2,1).and.beta.eq.size(matrix2,2)) then
        do n=1,alpha
           do m=1,beta
              diff=diff+(abs(matrix1(n,m)-matrix2(n,m)))**2
           enddo
        enddo
     else
        call ThrowException('Difference_btw_Matrices','Matrices of different shape',NoErrorCode,CriticalError)
     endif
     diff=sqrt(diff)
     return 

   end function Difference_btw_Matrices


 end module MPSTensor_Class
