!
!    This file is part of FortranMPS
!
!    FortranMPS is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    FortranMPS is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with FortranMPS.  If not, see <http://www.gnu.org/licenses/>.


!!  This module contains a class of objects with three legs as used by MPS algorithms.
!!  One leg is "special", it is the physical leg of the tensor.
!!  In notation it is nice to have the spin as the first index, but in the implementation 
!!  it is the third, as it makes it better for performance (this hasn't been checked, just intuition)

module MPSTensor_Class

  use ErrorHandling
  use Constants
  use Tensor_Class
  use Operator_Class

  implicit none

!  private

  public :: new_MPSTensor,LeftCanonize,RightCanonize
  public :: MPSTensor_times_matrix, matrix_times_MPSTensor , MPSTensor_times_MPSTensor

!###############################
!#####  The class main object
!###############################
  type,public,extends(Tensor3) :: MPSTensor
     private
   contains
     procedure,public :: getDRight => DRight_MPSTensor
     procedure,public :: getDLeft => DLeft_MPSTensor
     procedure,private :: DLeft => DLeft_MPSTensor
     procedure,private :: DRight => DRight_MPSTensor
     procedure,private :: spin => Spin_MPSTensor
     procedure,public :: getMaxBondDimension => Get_MaxBondDimensionMPSTensor
     procedure,public :: getSpin => Spin_MPSTensor
     procedure,public :: CollapseSpinWithBond => Collapse_Spin_With_Bond_Dimension
     procedure,public :: PrintDimensions => Print_MPSTensor_Dimensions
     procedure,public :: ApplyOperator => Apply_Operator_To_Spin_Dimension
     procedure,public :: SplitSpinDimension => Split_SpinDimension_ToObtainTensor4
     procedure,public :: BondTrace => MPSTraceBonds
  end type MPSTensor

!###############################
!#####  Operators and methods
!###############################
  interface new_MPSTensor
     module procedure new_MPSTensor_Random,new_MPSTensor_fromMPSTensor, &
          & new_MPSTensor_withConstant, new_MPSTensor_with_SplitData, &
          & new_MPSTensor_fromTensor3, new_MPSTensor_fromTensor3_Transposed
  end interface

  interface assignment (=)
     module procedure new_MPSTensor_fromAssignment
  end interface

  interface operator (.times.)
     module procedure MPSTensor_times_matrix, matrix_times_MPSTensor, MPSTensor_times_MPSTensor
  end interface

  interface operator (.xplus.)
     module procedure MPSTensor_times_matrix, matrix_times_MPSTensor, MPSTensor_times_MPSTensor
  end interface

  interface operator (.apply.)
     module procedure Apply_Operator_To_Spin_Dimension
  end interface

  interface MPSLeftProduct
     module procedure LeftProductTwoMPS,LeftProductOneMPS
  end interface

  interface MPSRightProduct
     module procedure RightProductTwoMPS,RightProductOneMPS
  end interface

  interface LeftCanonize
    module procedure Left_Canonize_MPSTensor
  end interface

  interface RightCanonize
    module procedure Right_Canonize_MPSTensor
  end interface

  interface SplitSpinFromBond
    module procedure Split_Spin_From_Bond_Dimension
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

     this=new_Tensor(DLeft,DRight,spin)

   end function new_MPSTensor_Random

!##################################################################
   function new_MPSTensor_with_SplitData (originalDataUP,originalDataDOWN) result (this)
     complex(8),intent(in) :: originalDataUP(:,:),originalDataDOWN(:,:)
     complex(8),allocatable :: JoinedData(:,:,:)
     type(MPSTensor) this
     integer :: upDims(2),downDims(2)

     upDims=shape(originalDataUP)
     downDims=shape(originalDataDOWN)

     if (upDims.equalvector.downDims) then
        allocate (JoinedData(upDims(1),upDims(2),2))
        JoinedData(:,:,1)=originalDataUP
        JoinedData(:,:,2)=originalDataDOWN

        this=new_Tensor(JoinedData)

      else
        call ThrowException('new_MPSTensor_with_SplitData','Up and down data have different size',upDims(1)-downDims(2),CriticalError)
      endif
   end function new_MPSTensor_with_SplitData

!##################################################################
   function new_MPSTensor_withConstant (spin,DLeft,DRight,constant) result (this)
     integer,intent(in) :: spin,DLeft,DRight
     complex(8),intent(in) :: constant
     type(MPSTensor) :: this

     this=new_Tensor(DLeft,DRight,spin,constant)

   end function new_MPSTensor_withConstant

!##################################################################
   function new_MPSTensor_fromMPSTensor (tensor) result (this)
     class(MPSTensor),intent(in) :: tensor
     type(MPSTensor) this

     this=new_Tensor(tensor)

   end function new_MPSTensor_fromMPSTensor

!##################################################################
   subroutine new_MPSTensor_fromAssignment(lhs,rhs)
     class(MPSTensor),intent(out) :: lhs
     type(MPSTensor),intent(in) :: rhs

     lhs=new_Tensor(rhs)

   end subroutine new_MPSTensor_fromAssignment

!##################################################################
   function new_MPSTensor_fromTensor3 (tensor) result (this)
     type(Tensor3),intent(in) :: tensor
     type(MPSTensor) this
     integer :: dims(3)

     this=new_Tensor(tensor)

   end function new_MPSTensor_fromTensor3

!##################################################################
   function new_MPSTensor_fromTensor3_Transposed (tensor,whichDimIsSpin,whichDimIsLeft,whichDimIsRight) result (this)
     type(Tensor3),intent(in) :: tensor
     integer, intent(IN) :: whichDimIsSpin,whichDimIsLeft,whichDimIsRight
     type(MPSTensor) this
     integer :: newDims(3)

     newDims(whichDimIsLeft)=1
     newDims(whichDimIsRight)=2
     newDims(whichDimIsSpin)=3
     this=TensorTranspose(tensor,newDims)

   end function new_MPSTensor_fromTensor3_Transposed

!##################################################################
!###########       Accessor methods
!##################################################################
   integer function spin_MPSTensor(this) result(s)
     class(MPSTensor),intent(IN) :: this
     integer :: dims(3)

    if(.not.(this%IsInitialized())) then
        call ThrowException('Spin','Tensor not initialized',NoErrorCode,Warning)
        return
     else
        dims=this%GetDimensions()
        s=dims(3)
     endif

   end function spin_MPSTensor
!##################################################################

   integer function DLeft_MPSTensor(this) result(DL)
     class(MPSTensor),intent(IN) :: this
     integer :: dims(3)

     if(.not.(this%IsInitialized())) then
        call ThrowException('DLeft','Tensor not initialized',NoErrorCode,Warning)
        return
     else
        dims=this%GetDimensions()
        DL=dims(1)
     endif

   end function DLeft_MPSTensor
!##################################################################
   integer function DRight_MPSTensor(this) result(DR)
     class(MPSTensor),intent(IN) :: this
     integer :: dims(3)

     if(.not.(this%IsInitialized())) then
        call ThrowException('DRight','Tensor not initialized',NoErrorCode,Warning)
        return
     else
        dims=this%GetDimensions()
        DR=dims(2)
     endif

   end function DRight_MPSTensor

   integer function Get_MaxBondDimensionMPSTensor(this) result(maxDimension)
     class(MPSTensor),intent(IN) :: this

     if(.not.(this%IsInitialized())) then
        call ThrowException('Get_MaxBondDimensionMPSTensor','Tensor not initialized',NoErrorCode,Warning)
        return
     else
        maxDimension=max(this%DRight(),this%DLeft())
     endif

   end function Get_MaxBondDimensionMPSTensor

    subroutine Print_MPSTensor_Dimensions(this,message)
        class(MPSTensor) :: this
        character*(*),optional :: message
        integer :: dims(3)

        if((this%IsInitialized())) then
            dims=this%GetDimensions()
            if (present(message) ) then
                write(*,'(A,", Spin: ",I3,", DLeft: ",I3,", DRight: ",I3)') ,message,dims(3),dims(1),dims(2)
            else
                write(*,'("Spin: ",I3,", DLeft: ",I3,", DRight: ",I3)') ,dims(3),dims(1),dims(2)
            endif
        else
            call ThrowException('DRight','Tensor not initialized',NoErrorCode,Warning)
            return
         endif

   end subroutine Print_MPSTensor_Dimensions


!##################################################################
!#######################        Products by things
!##################################################################

   function Apply_Operator_To_Spin_Dimension(this,anOperator) result(aTensor)
     class(MPSTensor),intent(IN) :: this
     type(MPSTensor) :: aTensor
     class(SpinOperator),intent(IN) :: anOperator
     integer :: opDims(2),tensorDims(3)

     opDims=anOperator%GetDimensions()
     if(this%IsInitialized()) then
        if(opDims(1).eq.this%spin().and.opDims(2).eq.this%spin()) then
           aTensor = new_Tensor(this*anOperator)
        else
           call ThrowException('Apply_Operator_To_Spin_Dimension','Operator is not of the right size',opDims(1)-opDims(2),CriticalError)
        endif
     else
        call ThrowException('Apply_Operator_To_Spin_Dimension','Tensor not initialized',NoErrorCode,CriticalError)
     endif

   end function Apply_Operator_To_Spin_Dimension

!##################################################################
    function MPSTensor_times_matrix(aTensor,aMatrix) result(theResult)
        class(MPSTensor),intent(IN) :: aTensor
        class(Tensor2),intent(IN) :: aMatrix
        type(MPSTensor) :: theResult

        theResult=TensorTranspose( TensorTranspose(aTensor,[1,3,2])*aMatrix , [1,3,2] )

    end function MPSTensor_times_matrix
!##################################################################
    function matrix_times_MPSTensor(aMatrix,aTensor) result(theResult)
        class(MPSTensor),intent(IN) :: aTensor
        class(Tensor2),intent(IN) :: aMatrix
        type(MPSTensor) :: theResult

        theResult=aMatrix*aTensor

    end function matrix_times_MPSTensor

!##################################################################

    function MPSTensor_times_MPSTensor(tensorA,tensorB) result(theResult)
        class(MPSTensor),intent(IN) :: tensorA,tensorB
        type(MPSTensor) :: theResult
        integer :: newDims(3)

        theResult=TensorTranspose( TensorTranspose(tensorA,[1,3,2]).xplus.TensorTranspose(tensorB,[1,3,2]), [1,3,2])

    end function MPSTensor_times_MPSTensor

!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

    function MPSTraceBonds(aTensor) result(aVector)
        class(MPSTensor),intent(IN) :: aTensor
        type(Tensor1) :: aVector

        aVector=aTensor%PartialTrace(THIRD)

    end function MPSTraceBonds

!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

   function LeftProductTwoMPS(LeftTensor,upMPSTensor,downMPSTensor,ShouldConjugate) result(theResult)
      class(MPSTensor),intent(IN) :: upMPSTensor,downMPSTensor
      class(Tensor2),intent(IN) :: LeftTensor
      integer,intent(IN),optional :: ShouldConjugate
      type(Tensor2) :: theResult

      If(present(ShouldConjugate).and.ShouldConjugate.eq.NO) then
        theResult=CompactLeft(LeftTensor,upMPSTensor,downMPSTensor,THIRD)
      else
        theResult=CompactLeft(LeftTensor,upMPSTensor,Conjugate(downMPSTensor),THIRD)
      endif

   end function LeftProductTwoMPS

   function LeftProductOneMPS(LeftTensor,anMPSTensor,ShouldConjugate) result(theResult)
      class(MPSTensor),intent(IN) :: anMPSTensor
      class(Tensor2),intent(IN) :: LeftTensor
      integer,intent(IN),optional :: ShouldConjugate
      type(Tensor2) :: theResult

      If(present(ShouldConjugate).and.ShouldConjugate.eq.NO) then
        theResult=CompactLeft(LeftTensor,anMPSTensor,anMPSTensor,THIRD)
      else
        theResult=CompactLeft(LeftTensor,anMPSTensor,Conjugate(anMPSTensor),THIRD)
      endif
   end function LeftProductOneMPS

   function RightProductTwoMPS(RightTensor,upMPSTensor,downMPSTensor,ShouldConjugate) result(theResult)
      class(MPSTensor),intent(IN) :: upMPSTensor,downMPSTensor
      class(Tensor2),intent(IN) :: RightTensor
      integer,intent(IN),optional :: ShouldConjugate
      type(Tensor2) :: theResult

      If(present(ShouldConjugate).and.ShouldConjugate.eq.NO) then
        theResult=CompactRight(RightTensor,upMPSTensor,downMPSTensor,THIRD)
      else
        theResult=CompactRight(RightTensor,upMPSTensor,Conjugate(downMPSTensor),THIRD)
      endif
   end function RightProductTwoMPS

   function RightProductOneMPS(RightTensor,anMPSTensor,ShouldConjugate) result(theResult)
      class(MPSTensor),intent(IN) :: anMPSTensor
      class(Tensor2),intent(IN) :: RightTensor
      integer,intent(IN),optional :: ShouldConjugate
      type(Tensor2) :: theResult

      If(present(ShouldConjugate).and.ShouldConjugate.eq.NO) then
          theResult=CompactRight(RightTensor,anMPSTensor,anMPSTensor,THIRD)
      else
          theResult=CompactRight(RightTensor,anMPSTensor,Conjugate(anMPSTensor),THIRD)
      endif
   end function RightProductOneMPS

!##################################################################
!##################################################################
!##################################################################
!##################################################################

    function Collapse_Spin_With_Bond_Dimension(this,whichDimension) result(collapsedTensor)
        class(MPSTensor),intent(IN) :: this
        integer,intent(IN) :: whichDimension
        type(Tensor2) :: collapsedTensor

        if(this%IsInitialized()) then
            select case (whichDimension)
                case (LEFT)
                    collapsedTensor=this%JoinIndices(THIRDANDFIRST,SECOND)
                case (RIGHT)
                    collapsedTensor=this%JoinIndices(FIRST,THIRDANDSECOND)
                case default
                    call ThrowException('Collapse_Spin_With_Bond_Dimension','Dimension must be FIRST or SECOND',whichDimension,CriticalError)
            end select
        else
            call ThrowException('Collapse_Spin_With_Bond_Dimension','Tensor not initialized',NoErrorCode,CriticalError)
        endif
        return
    end function Collapse_Spin_With_Bond_Dimension

!##################################################################

    function Split_Spin_From_Bond_Dimension(this,whichDimension,spinSize) result(splitTensor)
        class(Tensor2),intent(IN) :: this
        integer,intent(IN) :: whichDimension(1),spinSize
        type(MPSTensor) :: splitTensor
        integer :: newDims(3)

        if(this%IsInitialized()) then
            select case (whichDimension(1))
                case (FIRST(1))
                    splitTensor=TensorTranspose( SplitIndexOf(this,FIRST,spinSize), [3,1,2] )
                case (SECOND(1))
                    splitTensor=TensorTranspose( SplitIndexOf(this,SECOND,spinSize), [1,3,2] )
                case default
                    call ThrowException('Split_Spin_From_Bond_Dimension','Dimension must be FIRST or SECOND',whichDimension(1),CriticalError)
            end select
        else
            call ThrowException('Split_Spin_From_Bond_Dimension','Tensor not initialized',NoErrorCode,CriticalError)
        endif
        return
    end function Split_Spin_From_Bond_Dimension


!##################################################################

    function Split_SpinDimension_ToObtainTensor4(this,firstDimension,secondDimension) result(splitTensor)
        class(MPSTensor),intent(IN) :: this
        integer,intent(IN) :: firstDimension,secondDimension
        type(Tensor4) :: splitTensor

        if(this%IsInitialized()) then
            if (firstDimension*secondDimension.eq.this%spin()) then
                splitTensor= this%SplitIndex(THIRD,firstDimension)
            else
                call ThrowException('Split_SpinDimension_ToObtainTensor4','Requested partition does not match spin dimension', &
                    & firstDimension*secondDimension-this%spin(),CriticalError)
            endif
        else
            call ThrowException('Split_Spin_From_Bond_Dimension','Tensor not initialized',NoErrorCode,CriticalError)
        endif
        return
    end function Split_SpinDimension_ToObtainTensor4


!##################################################################
!##################################################################
! Right Site Canonization -- Returns the matrix that needs to be multiplied
! to the adjacent site on the RIGHT
!##################################################################
!##################################################################

  function Right_Canonize_MPSTensor(this) result(matrix)
    class(MPSTensor),intent(INOUT) :: this !
    type(Tensor2) :: matrix
    type(Tensor2) :: U,Sigma,V,collapsedTensor
    integer :: error,newUDims(2),oldDRight

    if(.not.this%IsInitialized()) then
       call ThrowException('Left_Canonize_MPSTensor','Tensor not initialized',NoErrorCode,CriticalError)
       return
    endif

    collapsedTensor=this%CollapseSpinWithBond(LEFT)

    if (WasThereError()) then
       call ThrowException('Left_Canonize_MPSTensor','Could not collapse the tensor',NoErrorCode,CriticalError)
       return
    endif
    error=Normal

    call SingularValueDecomposition(CollapsedTensor,U,Sigma,V)

    if (error.ne.Normal) then
       call ThrowException('Left_Canonize_MPSTensor','Could not split the matrix',NoErrorCode,CriticalError)
       return
    endif

    !We need to trim the matrix to get rid of useless dimensions
    newUDims=[ this%spin()*this%DLeft(), min(this%spin() * this%DLeft(), this%DRight())]
    oldDRight=this%DRight()
    this=SplitSpinFromBond( TensorPad(U,newUDims), FIRST, this%spin() )
    matrix=TensorPad(sigma*V, [ newUDims(2), oldDRight ] )

  end function Right_Canonize_MPSTensor

!##################################################################
!##################################################################
! Left Site Canonization -- Returns the matrix that needs to be multiplied
! to the adjacent site on the LEFT
!##################################################################
!##################################################################

  function Left_Canonize_MPSTensor(this) result(matrix)
    class(MPSTensor),intent(INOUT) :: this !
    type(Tensor2) :: matrix
    type(Tensor2) :: U,Sigma,V,collapsedTensor
    integer :: error,newVDims(2),oldDLeft

    if(.not.this%IsInitialized()) then
       call ThrowException('Left_Canonize_MPSTensor','Tensor not initialized',NoErrorCode,CriticalError)
       return
    endif

    collapsedTensor=this%CollapseSpinWithBond(RIGHT)
    if (WasThereError()) then
       call ThrowException('Left_Canonize_MPSTensor','Could not collapse the tensor',NoErrorCode,CriticalError)
       return
    endif

    error=Normal
    call SingularValueDecomposition(CollapsedTensor,U,Sigma,V)
    if (error.ne.Normal) then
       call ThrowException('Left_Canonize_MPSTensor','Error in SVD',NoErrorCode,CriticalError)
       return
    endif

    newVDims=[ min(this%spin() * this%DRight(), this%DLeft()), this%spin()*this%DRight()]
    oldDLeft=this%DLeft()

    !matrix is reshaped to fit the product with the tensor on the right
    this=SplitSpinFromBond( TensorPad(V,newVDims), SECOND, this%spin() )

    !matrix is reshaped to fit the product with the tensor on the right
    matrix=TensorPad( U*sigma, [ oldDLeft, newVDims(1) ] )

  end function Left_Canonize_MPSTensor

!#######################################################################################
!#######################################################################################


 end module MPSTensor_Class
