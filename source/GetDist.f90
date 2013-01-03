    ! Program to process .txt chain files produced by CosmoMC (cosmologist.info/cosmomc)
    ! Calculates statistics, thins, produces 1D and 2D marginalized plots and scatter plots
    ! and writes out useful information.
    ! Option to adjust priors and map parameters - write code below

    !Output files are (depending on options)

    ! * file_root.margestats - the mean, limits and stddev from the 1D marginalized distributions
    ! * file_root.likestats  - the best fit, and limits from the N-D confidence region
    ! * file_root.m          - MatLab .m file to produce 1D marginalized plots
    ! * file_root_2D.m       - MatLab .m file to produce 2D marginalized plots
    ! * file_root_3D.m       - MatLab .m file to produce 2D sample plots colored by a third parameter
    ! * file_root_tri.m      - MatLab .m file to produce triangle plots (1D on diagonal, 2D off-diagonal)
    ! * file_root_thin.txt   - thinned merged versions of input files
    ! * file_root.covmat     - covariance matrix for parameters
    ! * file_root.corr       - covariance matrix for parameters normalized to have unit variance
    ! * file_root.PCA        - human-readable file giving details of PCA, constrained parameters, etc
    ! * file_root.converge   - Various statistics to help assess chain convergence/sampling error

    ! You can easily edit the .m files produced to produce custom layouts of plots, etc.
    ! Data for plots are exported to the plot_data_dir folder, other files to out_dir

    !March 03: fixed bug computing the limits in the .margestats file
    !May 03: Added support for triangle plots
    !Dec 03: Support for non-chain samples, auto-correlation convergence, auto_label,
    !         split tests to quanify sampling error on upper and lower quantiles
    !Jan 05: MatLab 7 options, various minor changes
    !Jul 05: Added limits info to .margestats output
    !Apr 06: Fixed some version confusions
    !Aug 06: speeded 2D plotting, added limitsxxx support with smoothing=F
    !Oct 06: Added plot_data_dir and out_dir
    !Nov 07: uses Matrix_utils, fixed .ps file output filenames,
    !        added markerxxx for vertical lines in 1D matlabl plots
    !May 08: Option to process WMAP5-formatted chains (thanks to Mike Nolta)
    !        Added do_minimal_1d_intervals for equal-likelihood 1D limits (thanks to Jan Hamann, see arXiv:0705.0440)
    !        Added font_scale to scale default font sizes, num_contours input parameter (allows more than 2)
    !Sept 09: use of .paramnames and parameter_names file for names and labels; referencing by name as alternative to number
    !         allowed map_params with 1-column input format
    !         plotparams parameter ordering is preserved (e.g. to change order of 1D plots)
    !Oct 09:  fixed bug in credible intervals with prior cutoffs (Jan Hammann)
    !May 10:  added finish_run_command to run system command when getdist finished (e.g. "matlab < %ROOTNAME%.m")
    !          added line_labels to write out roots of lines being plotted (matlab)
    !          added no_triangle_axis_labels
    !Jan 11:  fix to confidence interval calcaultion for obscure cases with very empty tails (thanks Andrew Fowlie)
    !Jan 12:  increased precision of output files
    !Oct 12:  matlab_plot_output for pdf,eps,ps output support; matlab_subplot_size_inch
    !         fix for more than 100 parameters
    !Nov-Dec 12: removed sm support; use specific parameter in triangle plots; new R-1 definition, etc...
    module MCSamples
    use settings
    use MatrixUtils
    use ParamNames
    use Samples
    implicit none

    integer, parameter :: gp = KIND(1.d0)

    ! #define coldata(a, b) coldata(b, a)
    !uncomment to switch order for compilation so confid_val is faster - suggested by Reijo Keskitalo March07

    real(gp), dimension(:,:), target, allocatable :: coldata  !(col_index, row_index)
    integer, dimension(:), allocatable :: thin_ix
    integer thin_rows

    integer, parameter :: max_rows = 500000
    integer, parameter :: max_cols = 500
    integer, parameter :: max_chains = 100
    integer, parameter :: max_split_tests = 4
    integer, parameter :: max_intersections = 10 !JH: increase if posterior has more than five peaks
    integer, parameter :: max_contours = 5

    integer chain_indices(max_chains), num_chains_used

    integer nrows, ncols
    real(mcp) numsamp
    integer ND_cont1, ND_cont2
    integer covmat_dimension
    integer colix(max_cols), num_vars  !Parameters with non-blank labels
    real(mcp) mean(max_cols), sddev(max_cols)
    real(mcp), dimension(:,:), allocatable :: corrmatrix
    character(LEN=Ini_max_string_len) rootname, plot_data_dir, out_dir, &
    rootdirname, in_root
    character(LEN=128) labels(max_cols)
    character(LEN=128) pname(max_cols)
    logical has_limits(max_cols), has_limits_top(max_cols),has_limits_bot(max_cols)
    logical has_markers(max_cols)
    real(mcp) markers(max_cols)
    integer num_contours
    real(mcp) matlab_version
    character(LEN=3) :: matlab_plot_output = 'eps'
    real :: matlab_subplot_size_inch = 3.0
    real :: matlab_subplot_size_inch2, matlab_subplot_size_inch3

    logical :: matlab_latex = .false.
    real(mcp) :: font_scale = 1.
    real(mcp) contours(max_contours)
    real(mcp) mean_mult, max_mult
    integer :: indep_thin = 0
    integer chain_numbers(max_chains)
    logical isused(max_cols)
    logical force_twotail
    logical smoothing, plot_meanlikes, plot_NDcontours
    logical shade_meanlikes, make_single_samples
    integer single_thin,cust2DPlots(max_cols**2)
    integer ix_min(max_cols),ix_max(max_cols)
    real(mcp) center(max_cols),width(max_cols)
    real(mcp), dimension(:,:), allocatable :: TheBins, bins2D, bin2Dlikes, bin2Dmax
    real(mcp) meanlike, maxlike, maxmult
    logical BW,do_shading
    character(LEN=Ini_max_string_len), allocatable :: ComparePlots(:)
    integer Num_ComparePlots
    logical ::   prob_label = .false.
    logical :: plots_only

    contains

    subroutine AdjustPriors
    !Can adjust the multiplicity of each sample in coldata(1, rownum) for new priors
    !Be careful as this code is parameterisation dependent
    !  integer i
    !   real(mcp) ombh2, chisq

    stop 'You need to write the AdjustPriors subroutine in GetDist.f90 first!'

    !   write (*,*) 'Adjusting priors'
    !   do i=0, nrows-1
    !!E.g. ombh2 prior
    !      ombh2 = coldata(1+2,i)
    !      chisq = (ombh2 - 0.0213)**2/0.001 **2
    !      coldata(1,i) = coldata(1,i)*exp(-chisq/2)
    !      coldata(2,i) = coldata(2,i) + chisq/2
    !
    !   end do

    end subroutine AdjustPriors

    subroutine MapParameters(invars)
    real(gp) invars(1:ncols)
    ! map parameters in invars: eg. invars(3)=invars(3)*invars(4)

    !    invars(2+13)=invars(17+2)*exp(-invars(2+4))
    stop 'Need to write MapParameters routine first'

    end subroutine MapParameters

    subroutine CoolChain(cool)
    real(mcp), intent(in) :: cool
    integer i
    real(mcp) maxL, newL

    write (*,*) 'Cooling chains by ', cool
    MaxL = minval(coldata(2,0:nrows-1))
    do i=0, nrows-1
        newL = coldata(2,i)*cool
        coldata(1,i) = coldata(1,i)*exp(-(newL - coldata(2,i)) - MaxL*(1-cool) )
        coldata(2,i) = newL
    end do

    end subroutine CoolChain

    subroutine DeleteZeros
    integer i,ii

    ii=0
    do i=0, nrows-1
        if (coldata(1,i)/=0) then
            coldata(:,ii) = coldata(:,i)
            ii=ii+1
        end if
    end do
    if (ii==0) stop 'Prior has removed all models!'
    if (ii /= nrows) write (*,*) 'Prior removed ',nrows-ii,'models'
    nrows = ii

    end subroutine DeleteZeros

    subroutine SortColData(bycol)
    !Sort coldata in order of likelihood
    integer, intent(in) :: bycol
    integer i
    Type(TSampleList) :: S

    call S%SetCapacity(nrows)
    do i = 0, nrows -1
        call S%Add(coldata(1:ncols,i))
    end do

    call S%SortArr(bycol)
    do i = 0, nrows-1
        coldata(1:ncols,i) =  S%Item(i+1)
    end do
    call S%Clear()
    end  subroutine SortColData


    subroutine MakeSingleSamples(single_thin)
    !Make file of weight-1 samples by choosing samples with probability given by their weight
    use Random
    integer i, single_thin
    character(LEN=20) :: fmt

    real(mcp) maxmult
    Feedback = 0
    call initRandom()
    fmt = trim(numcat('(',num_vars+2))//'E16.7)'

    open(unit=50,file=trim(plot_data_dir)//trim(rootname)//'_single.txt',form='formatted',status='replace')
    maxmult = maxval(coldata(1,0:nrows-1))
    do i= 0, nrows -1
        if (ranmar() <= coldata(1,i)/maxmult/single_thin) write (50,fmt) 1.0, coldata(2,i), coldata(colix(1:num_vars),i)
    end do
    close(50)

    end subroutine MakeSingleSamples

    subroutine WriteThinData(fname,cool)
    character(LEN=*), intent(in) :: fname
    real(mcp),intent(in) :: cool

    character(LEN=20) :: fmt
    integer i
    real(mcp) MaxL, NewL

    if (cool /= 1) write (*,*) 'Cooled thinned output with temp: ', cool

    MaxL = minval(coldata(2,0:nrows-1))

    fmt = trim(numcat('(',ncols))//'E16.7)'
    open(unit=50,file=fname,form='formatted',status='replace')

    do i=0, thin_rows -1
        if (cool/=1) then
            newL = coldata(2,thin_ix(i))*cool
            write (50,fmt) exp(-(newL - coldata(2,thin_ix(i))) - MaxL*(1-cool) ), newL, &
            coldata(3:ncols,thin_ix(i))
        else
            write (50,fmt) 1., coldata(2:ncols,thin_ix(i))
        end if
    end do
    write (*,*) 'Wrote ',thin_rows, 'thinned samples'
    close(50)

    end subroutine WriteThinData


    subroutine ThinData(fac, ix1,ix2)
    !Make thinned samples

    integer, intent(in) :: fac
    integer, intent(in), optional :: ix1,ix2
    integer i, tot, nout, nend, mult

    if (allocated(thin_ix)) deallocate(thin_ix)
    allocate(thin_ix(0:nint(numsamp)/fac))

    tot= 0
    nout=0
    i = 0
    if (present(ix1)) i=ix1
    nend = nrows
    if (present(ix2)) nend = ix2+1

    mult = coldata(1,i)
    do while (i< nend)

    if (abs(nint(coldata(1,i)) - coldata(1,i)) > 1e-4) &
    stop 'non-integer weights in ThinData'

    if (mult + tot < fac) then
        tot = tot + mult
        i=i+1
        if (i< nend) mult = nint(coldata(1,i))
    else
        thin_ix(nout) = i
        nout= nout+1
        if (mult == fac - tot) then
            i=i+1
            if (i< nend) mult = nint(coldata(1,i))
        else
            mult = mult - (fac -tot)
        end if
        tot = 0
    end if

    end do

    thin_rows = nout

    close(50)

    end subroutine ThinData


    subroutine GetCovMatrix
    use IO
    integer i, j, nused
    real(mcp) mean(max_cols)
    real(mcp) scale
    real(mcp), dimension(:,:), allocatable :: covmatrix
    integer used_ix(max_cols)
    character(LEN=4096) outline

    allocate(corrmatrix(ncols-2,ncols-2))

    corrmatrix = 0
    nused = 0
    do i=1, ncols-2
        if (isused(i+2)) then
            if (i <= NameMapping%num_MCMC) then
                nused = nused + 1
                used_ix(nused)=i
            end if
            mean(i) = sum(coldata(1,0:nrows-1)*coldata(i+2,0:nrows-1))/numsamp
        end if
    end do

    do i = 1, ncols-2
        if (isused(i+2)) then
            do j = i, ncols-2
                if (isused(j+2)) then
                    corrmatrix(i,j) = sum(coldata(1,0:nrows-1)*((coldata(2+i,0:nrows-1)-mean(i))* &
                    (coldata(2+j,0:nrows-1)-mean(j))))/numsamp
                    corrmatrix(j,i) = corrmatrix(i,j)
                end if
            end do
        end if
    end do

    if (NameMapping%nnames/=0) then
        outline=''
        do i=1, nused
            outline = trim(outline)//' '//trim(ParamNames_name(NameMapping,used_ix(i)))
        end do
        allocate(covmatrix(nused,nused))
        covmatrix = corrmatrix(used_ix(1:nused),used_ix(1:nused))
        call IO_WriteProposeMatrix(covmatrix,trim(rootdirname) //'.covmat', outline)
        !               call Matrix_write(trim(rootdirname) //'.covmat',covmatrix,.true.,commentline=outline)
        deallocate(covmatrix)
    else
        if (covmat_dimension /= 0 .and. .not. plots_only) then
            if (covmat_dimension > ncols -2) stop 'covmat_dimension larger than number of parameters'
            write (*,*) 'Writing covariance matrix for ',covmat_dimension,' parameters'
            allocate(covmatrix(covmat_dimension,covmat_dimension))
            covmatrix=corrmatrix(1:covmat_dimension,1:covmat_dimension)
            call IO_WriteProposeMatrix(covmatrix,trim(rootdirname) //'.covmat')
            !               call Matrix_write(trim(rootdirname) //'.covmat',covmatrix,.true.)
            deallocate(covmatrix)
        end if
    end if

    do i=1, ncols-2
        if (corrmatrix(i,i) > 0) then
            scale = sqrt(corrmatrix(i,i))
            corrmatrix(i,:) = corrmatrix(i,:)/scale
            corrmatrix(:,i) = corrmatrix(:,i)/scale
        end if
    end do
    if (.not. plots_only) call Matrix_write(trim(rootdirname) //'.corr',corrmatrix, .true.)

    end subroutine GetCovMatrix


    function MostCorrelated2D(i1,i2, direc)
    integer, intent(in) :: i1,i2, direc
    integer MostCorrelated2D
    !Find which parameter is most correllated with the degeneracy in ix1, ix2
    integer pars(2)
    real(mcp) mat2D(2,2), evals(2), u(2,2)
    real(mcp) corrs(2,ncols-2)

    if (direc /= 0 .and. direc /= -1) stop 'Invalid 3D color parameter'

    pars(1)=i1
    pars(2)=i2
    mat2D = corrmatrix(pars,pars)
    u = mat2D

    call Matrix_Diagonalize(u, evals, 2)
    corrs = matmul(transpose(u), corrmatrix(pars,:))
    corrs(:,pars) = 0

    MostCorrelated2D = MaxIndex(real(abs(corrs(2+direc,colix(1:num_vars)-2))), num_vars)
    MostCorrelated2D = colix(MostCorrelated2D) -2

    end function MostCorrelated2D

    subroutine GetFractionIndices(fraction_indices,n)
    integer, intent(in) :: n
    integer num, fraction_indices(*), i
    real(mcp) tot, aim

    tot = 0
    aim=numsamp/n
    num = 1
    fraction_indices(1) = 0
    fraction_indices(n+1) = nrows
    do i=0, nrows-1
        tot = tot + coldata(1,i)
        if (tot > aim) then
            num=num+1
            fraction_indices(num) = i
            if (num==n) exit
            aim=aim+numsamp/n
        end if
    end do

    end subroutine GetFractionIndices

    function ConfidVal(ix,limfrac,upper,ix1,ix2)
    integer, intent(IN) :: ix
    real(mcp), intent(IN) :: limfrac
    logical, intent(IN) :: upper
    integer, intent(IN), optional :: ix1,ix2
    real(mcp) ConfidVal, samps
    real(mcp) try, lasttry, try_t, try_b
    integer l,t
    !find upper and lower bounds

    l=0
    t=nrows-1
    if (present(ix1)) l=ix1
    if (present(ix2)) t = ix2
    try_b = minval(coldata(ix,l:t))
    try_t = maxval(coldata(ix,l:t))

    samps = sum(coldata(1,l:t))

    lasttry = -1
    if (upper) then
        do
            try = sum(coldata(1,l:t),mask = coldata(ix,l:t) > (try_b + try_t)/2)
            if (try > samps*limfrac) then
                try_b = (try_b+try_t)/2
            else
                try_t = (try_b+try_t)/2
            end if
            if (try == lasttry .and. (abs(try_b + try_t)< 1e-10_mcp &
            .or. abs((try_b - try_t)/(try_b + try_t)) < 0.05_mcp )) exit
            lasttry = try
        end do
    else
        do
            try = sum(coldata(1,l:t),mask = coldata(ix,l:t) < (try_b + try_t)/2)
            if (try > samps*limfrac) then
                try_t = (try_b+try_t)/2
            else
                try_b = (try_b+try_t)/2
            end if
            if (try == lasttry .and. (abs(try_b + try_t)< 1e-10_mcp &
            .or. abs((try_b - try_t)/(try_b + try_t)) < 0.05_mcp )) exit
            lasttry = try
        end do
    end if

    ConfidVal = try_t
    end function ConfidVal

    !!!!!!!!!!!!!!!!!!!!!!!!!!!! JH: beginning of MCI stuff !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    ! Find intersection of counts = x with linearly interpolated marginalised posterior
    subroutine GetZeros(bincounts,botlim,toplim,minbin,maxbin,x,numzeros,zeros)
    logical, intent(IN) :: botlim,toplim
    integer, intent(IN) :: minbin,maxbin
    real(mcp), intent(IN) :: bincounts(-1000:1000)
    real(mcp), intent(IN) :: x
    real(mcp), intent(OUT), dimension(max_intersections) :: zeros
    integer, intent(OUT) :: numzeros
    integer i

    zeros=0
    numzeros=0

    do i=-1000,999 ! identify intersections
        if(((bincounts(i).lt.x).and.(bincounts(i+1).ge.x)) &
        &.or.((bincounts(i).ge.x).and.(bincounts(i+1).lt.x))) then

        numzeros = numzeros+1

        if (toplim .and.(i.eq. maxbin)) then ! identify intersections at limits
            zeros(numzeros)=i
        else if (botlim .and. (i.eq. minbin-1)) then
            zeros(numzeros)=i+1
        else ! otherwise do linear interpolation
            zeros(numzeros)=i+(x-bincounts(i))/(bincounts(i+1)-bincounts(i))
        end if
        end if
    end do

    end subroutine GetZeros



    function MinInterval(conflev,bincounts,width,center,botlim,toplim,minbin,maxbin)
    ! find minimum length 1d confidence intervals
    logical, intent(IN) :: botlim,toplim
    integer, intent(IN) :: minbin,maxbin
    integer i,lbin
    real(mcp), intent(IN) :: conflev,width,center
    real(mcp), intent(IN) :: bincounts(-1000:1000)
    real(mcp), dimension(max_intersections+1) :: MinInterval
    real(mcp) :: try,try_t,try_b,try_last,try_sum,norm
    real(mcp) :: waterlevel
    real(mcp), dimension(max_intersections) :: zeros
    integer :: numzeros

    norm = sum(bincounts)
    if (toplim) norm = norm - 0.5*bincounts(maxbin)
    if (botlim) norm = norm - 0.5*bincounts(minbin)

    try_t = maxval(bincounts)
    try_b = 0
    try_last = -1

    ! Iteration to find the number of counts x, such that the integral over the interval where the marginalised posterior
    ! is larger than x/norm gives the desired credibility level. Uses linear interpolation between bins.

    do
        try = (try_b + try_t)/2

        call GetZeros(bincounts,botlim,toplim,minbin,maxbin,try,numzeros,zeros) ! find integration limits

        try_sum = sum(bincounts,mask = bincounts .ge. (try_b + try_t)/2) ! step function approximation of integral

        do i=1,numzeros/2
            if (zeros(2*i-1).gt.0) then
                lbin = int(zeros(2*i-1))
            else
                lbin = int(zeros(2*i-1))-1
            end if

            ! corrections for left (odd) intersection(s) of posterior with trial number of counts
            try_sum=try_sum-.5*bincounts(lbin+1)+(lbin+1-zeros(2*i-1))*(bincounts(lbin+1)-0.5* &
            ((bincounts(lbin+1)-bincounts(lbin))*(lbin+1-zeros(2*i-1))))

            if (zeros(2*i).gt.0) then
                lbin = int(zeros(2*i))
            else
                lbin = int(zeros(2*i))-1
            end if

            ! corrections for right (even) intersection(s) of posterior with trial number of counts
            try_sum=try_sum-.5*bincounts(lbin)+(zeros(2*i)-lbin)*(bincounts(lbin)-.5*((zeros(2*i)-lbin)* &
            (bincounts(lbin)-bincounts(lbin+1))))
        end do

        if (try_sum < conflev*norm) then
            try_t = (try_b+try_t)/2
        else
            try_b = (try_b+try_t)/2
        end if
        if (abs(try_sum/try_last - 1) .lt. 0.001) exit
        try_last = try_sum

    end do

    waterlevel = (try_b+try_t)/2


    call GetZeros(bincounts,botlim,toplim,minbin,maxbin,waterlevel,numzeros,zeros)


    MinInterval(max_intersections+1)=real(numzeros) ! store number of intersections in last entry of vector

    do i=1,max_intersections
        MinInterval(i) = zeros(i)*width+center ! translates bin # into parameter values
        if (botlim .and.toplim .and.(zeros(i) .eq. minbin)) then
            MinInterval(i) = nint(1.e5*MinInterval(i))/1.e5
            ! takes care of rounding errors if parameter has both upper and lower limits
        end if
    end do

    end function MinInterval

    !!!!!!!!!!!!!!!!!!!!!!!!!!!! JH: end of MCI stuff !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


    subroutine PCA(pars,n,param_map,normparam_num)
    !Perform principle component analysis
    !In other words, get eigenvectors and eigenvalues for normalized variables
    !with optional (log) mapping
    integer, intent(in) :: n, pars(n), normparam_num
    character(LEN=*), intent(IN) ::  param_map
    integer i, j, normparam, locarr(1:1)
    character(LEN =60) fmt, tmpS

    real(mcp) PCmean(n), sd(n), newmean(n), newsd(n)
    real(mcp) evals(n)
    real(mcp) corrmatrix(n,n), u(n,n)
    real(mcp), dimension(:,:), allocatable :: PCdata
    character(LEN=100) PClabs(n), div, expo
    logical doexp


    write (*,*) 'Doing PCA for ',n,' parameters'
    call CreateTxtFile(trim(rootdirname) //'.PCA', 40)
    write (40,*) 'PCA for parameters: '

    if (normparam_num /=0) then
        normparam = IndexOf(normparam_num,pars,n)
        if (normparam ==0) stop 'Invalid PCA normalization parameter'
    else
        normparam = 0
    end if

    allocate(PCdata(n,0:nrows-1))

    PCdata(:,:) = coldata(2+pars,0:nrows-1)
    fmt = trim(numcat('',n))//'f8.4)'

    doexp =.false.
    do i = 1, n
        if (param_map(i:i)=='L') then
            doexp = .true.
            PCdata(i,:) = log(PCdata(i,:))
            PClabs(i) = 'ln(' //trim(labels(pars(i)+2))//')'
        elseif (param_map(i:i)=='M') then
            doexp = .true.
            PCdata(i,:) = log(-PCdata(i,:))
            PClabs(i) = 'ln(-' //trim(labels(pars(i)+2))//')'
        else
            PClabs(i) = trim(labels(pars(i)+2))
        end if
        write (40,*) pars(i),':',trim(PClabs(i))
        PCmean(i) = sum(coldata(1,0:nrows-1)*PCdata(i,:))/numsamp
        PCdata(i,:) = PCdata(i,:) - PCmean(i)
        sd(i) = sqrt(sum(coldata(1,0:nrows-1)*PCdata(i,:)**2)/numsamp)
        if (sd(i)/=0) PCdata(i,:) = PCdata(i,:)/sd(i)
        corrmatrix(i,i) = 1
    end do

    write (40,*) ''
    write (40,*) 'Correlation matrix for reduced parameters'
    do i = 1, n
        do j = i, n
            corrmatrix(i,j) = sum(coldata(1,0:nrows-1)*PCdata(i,:)*PCdata(j,:))/numsamp
            corrmatrix(j,i) = corrmatrix(i,j)
        end do
        write (40,'(1I4,'': '','//trim(fmt)) pars(i), corrmatrix(i,:)
    end do

    u = corrmatrix
    call Matrix_Diagonalize(u, evals, n)

    write (40,*) ''
    write (40,*) 'e-values of correlation matrix'
    do i = 1, n
        write (40,'(''PC'',1I2,'': '','//trim(fmt)) i, evals(i)
    end do

    write (40,*) ''
    write (40,*) 'e-vectors'

    do i = 1, n
        write (40,'(1I3,'': '','//trim(fmt)) pars(i), u(i,:)
    end do


    if (normparam /= 0) then
        !Set so parameter normparam has exponent 1
        do i=1, n
            u(:,i) = u(:,i)/u(normparam,i)*sd(normparam)
        end do
    else
        !Normalize so main component has exponent 1
        do i=1, n
            locarr(1:1) = maxloc(abs(u(:,i)))
            u(:,i) = u(:,i)/u(locarr(1),i)*sd(locarr(1))
        end do
    end if

    do i = 0, nrows -1
        PCdata(:,i) = matmul(transpose(u), PCdata(:,i))
        if (doexp) PCdata(:,i) = exp(PCdata(:,i))
    end do

    write (40,*) ''
    write (40,*) 'Principle components'

    do i = 1, n
        tmpS = trim(numcat('PC',i))//' (e-value: '//trim(RealToStr(evals(i)))//')'
        !ifc gives recursive IO error if you use a write within a write,
        !even if separate or internal files
        write (40,*) trim(tmpS)
        do j=1,n
            if (param_map(j:j)=='L' .or. param_map(j:j)=='M' ) then
                expo = RealToStr(1/sd(j)*u(j,i) )
                if (param_map(j:j)=='M') then
                    div = RealToStr( -exp(PCmean(j)))
                else
                    div = RealToStr( exp(PCmean(j)))
                end if
                write(40,*) '['//trim(RealToStr(u(j,i)))//']   ('//trim(labels(pars(j)+2)) &
                //'/'//trim(div)//')^{'//trim(expo)//'}'
            else
                expo = RealToStr(sd(j)/u(j,i))
                if (doexp) then
                    write(40,*) '['//trim(RealToStr(u(j,i)))//']    exp(('// &
                    trim(labels(pars(j)+2))//'-'//trim(RealToStr(PCmean(j)))// ')/'// trim(expo)//')'
                else
                    write(40,*) '['//trim(RealToStr(u(j,i)))//']   ('// &
                    trim(labels(pars(j)+2))//'-'//trim(RealToStr(PCmean(j)))// ')/'// trim(expo)
                end if
            end if

        end do
        newmean(i) = sum(coldata(1,0:nrows-1)*PCdata(i,:))/numsamp
        newsd(i) = sqrt(sum(coldata(1,0:nrows-1)*(PCdata(i,:)-newmean(i))**2)/numsamp)
        write (40,*) '          = '//trim(RealToStr(newmean(i)))// ' +- '//trim(RealToStr(newsd(i)))
        write (40,'('' ND limits: '',4f9.3)') minval(PCdata(i,0:ND_cont1)),maxval(PCdata(i,0:ND_cont1)), &
        minval(PCdata(i,0:ND_cont2)),maxval(PCdata(i,0:ND_cont2))
        write (40,*) ''

    end do

    !Find out how correlated these components are with other parameters
    write (40,*) 'Correlations of principle components'

    write (40,trim(numcat('(''    '',',n))//'I8)') (I, I=1, n)

    do i=1, n
        PCdata(i,:) = (PCdata(i,:) - newmean(i)) /newsd(i)
    end do

    do j=1,n
        write (40,'(''PC'',1I2)', advance = 'no') j
        do i=1,n
            write (40,'(1f8.3)', advance ='no') sum(coldata(1,0:nrows-1)*PCdata(i,:)* &
            PCdata(j,:))/numsamp
        end do
        write (40,*) ''
    end do

    do j=1, num_vars
        write (40,'(1I4)', advance = 'no') colix(j)-2
        do i=1,n
            write (40,'(1f8.3)', advance ='no') sum(coldata(1,0:nrows-1)*PCdata(i,:)* &
            (coldata(colix(j),0:nrows-1)-mean(j))/sddev(j))/numsamp
        end do
        write (40,*) '  ('//trim(labels(colix(j)))//')'
    end do


    close(40)
    deallocate(PCdata)

    end subroutine PCA

    subroutine GetUsedCols
    integer j

    do j = 3, ncols
        isused(j) = any(coldata(j,0:nrows-1)/=coldata(j,0))
    end do
    end subroutine GetUsedCols

    subroutine DoConvergeTests
    real(mcp) chain_means(max_chains,max_cols),chain_samp(max_chains)
    real(mcp) between_chain_var(max_cols), in_chain_var(max_cols)
    integer frac(max_split_tests+1), split_n, chain_start(max_chains)
    integer i,j,k,jj,kk,ix, maxoff
    real(mcp) split_tests(max_split_tests)
    real(mcp) mean(max_cols), fullmean(max_cols),fullvar(max_cols)
    real(mcp), parameter :: cutfrac = 0._mcp
    real(mcp) usedsamps,evals(max_cols),R, maxsamp
    real(mcp), dimension(:,:), allocatable :: cov, meanscov
    integer usedvars(max_cols), num, thin_fac(max_chains), markov_thin(max_chains)
    real(gp) u, g2, fitted, focus, alpha, beta, probsum, tmp1
    real(mcp) confid
    integer i1,i2,i3, nburn(max_chains), hardest, endb,hardestend
    integer tran(2,2,2), tran2(2,2), off
    integer, dimension(:), allocatable :: binchain
    real(mcp), parameter :: epsilon = 0.001
    double precision, dimension(:,:), allocatable :: corrs
    character(LEN=10) :: typestr
    integer autocorr_thin

    ! Get statistics for individual chains, and do split tests on the samples

    call CreateTxtFile(trim(rootdirname) //'.converge', 40)

    if (num_chains_used > 1) write (*,*) 'Number of chains used =  ',num_chains_used

    chain_indices(num_chains_used+1) = nrows
    do i=1, num_chains_used
        chain_start(i) =  chain_indices(i) + nint((chain_indices(i+1)-chain_indices(i))*cutfrac)
        chain_samp(i) = sum(coldata(1,chain_start(i):chain_indices(i+1)-1))
    end do
    usedsamps = sum(chain_samp(1:num_chains_used))
    maxsamp = maxval(chain_samp(1:num_chains_used))
    num = 0
    do j = 3, ncols
        if (isused(j)) then
            mean(j)=0
            fullmean(j) =  sum(coldata(1,0:nrows-1)*coldata(j,0:nrows-1))/numsamp

            if (num_chains_used> 1) then
                num=num+1
                usedvars(num)=j
                do i=1, num_chains_used
                    mean(j) = mean(j) + sum(coldata(1,chain_start(i):chain_indices(i+1)-1)*&
                    coldata(j,chain_start(i):chain_indices(i+1)-1))
                end do
                mean(j) = mean(j)/usedsamps
            end if
        end if
    end do

    do j = 3, ncols
        if (isused(j)) &
        fullvar(j)=  sum(coldata(1,0:nrows-1)*(coldata(j,0:nrows-1)-fullmean(j))**2)/numsamp
    end do


    if (num_chains_used > 1) then

    write (40,*) ''
    write(40,*)  'Variance test convergence stats using remaining chains'
    write (40,*) 'param var(chain mean)/mean(chain var)'
    write (40,*) ''

    do j = 3, ncols
        between_chain_var(j) = 0
        in_chain_var(j) = 0

        if (isused(j)) then

        if (num_chains_used > 1) then
            !Get stats for individual chains - the variance of the means over the mean of the variances
            do i=1, num_chains_used
                chain_means(i,j) =   sum(coldata(1,chain_start(i):chain_indices(i+1)-1)* &
                coldata(j,chain_start(i):chain_indices(i+1)-1))/chain_samp(i)

                between_chain_var(j) = between_chain_var(j) + &
                ! chain_samp(i)/maxsamp* & !Weight for different length chains
                (chain_means(i,j) - mean(j))**2

                in_chain_var(j) = in_chain_var(j) +  & !chain_samp(i)/maxsamp *&
                sum(coldata(1,chain_start(i):chain_indices(i+1)-1)* &
                (coldata(j,chain_start(i):chain_indices(i+1)-1)-chain_means(i,j))**2)

            end do
            between_chain_var(j) = between_chain_var(j)/(num_chains_used-1) !(usedsamps/maxsamp -1)
            in_chain_var(j) = in_chain_var(j)/usedsamps
            write (40,'(1I3,f9.4,"  '//trim(labels(j))//'")') j-2, &
            between_chain_var(j) /in_chain_var(j)
        end if

        end if
    end do

    end if

    if (num_chains_used > 1 .and. covmat_dimension>0) then
        !Assess convergence in the var(mean)/mean(var) in the worst eigenvalue
        !c.f. Brooks and Gelman 1997

        do while (usedvars(num) > covmat_dimension+2)
            num= num - 1
        end do

        allocate(meanscov(num,num))
        allocate(cov(num,num))

        do jj=1,num
            j=usedvars(jj)
            do kk=jj, num
                k = usedvars(kk)
                meanscov(jj,kk) =0
                cov(jj,kk)= 0
                do i= 1, num_chains_used
                    cov(jj,kk) = cov(jj,kk) + &
                    !sqrt(chain_samp(jj)*chain_samp(kk))/maxsamp * &
                    sum(coldata(1,chain_start(i):chain_indices(i+1)-1)* &
                    (coldata(j,chain_start(i):chain_indices(i+1)-1)-chain_means(i,j))* &
                    (coldata(k,chain_start(i):chain_indices(i+1)-1)-chain_means(i,k)))

                    meanscov(jj,kk) = meanscov(jj,kk)+ & !sqrt(chain_samp(jj)*chain_samp(kk))/maxsamp * &
                    (chain_means(i,j)-mean(j))*(chain_means(i,k)-mean(k))
                end do
                meanscov(kk,jj) = meanscov(jj,kk)
                cov(kk,jj) = cov(jj,kk)

            end do
        end do
        meanscov = meanscov/(num_chains_used-1) !(usedsamps/maxsamp -1)
        cov = cov / usedsamps

        call GelmanRubinEvalues(cov, meanscov, evals, num)
        write (40,*) ''
        write (40,'(a)') 'var(mean)/mean(var) for eigenvalues of covariance of means of orthonormalized parameters'
        R = 0
        do jj=1,num
            write (40,'(1I3,f9.4)') jj,evals(jj)
            R = max(R,evals(jj))
        end do
        !R is essentially the Gelman and Rubin statistic
        write (*,'(" var(mean)/mean(var), remaining chains, worst e-value: R-1 = ",f9.4)') R
        deallocate(cov,meanscov)
    end if


    !Do tests for robustness under using splits of the samples
    !Return the rms ([change in upper/lower quantile]/[standard deviation])
    !when data split into 2, 3,.. sets
    write (40,*) ''
    write (40,*)  'Split tests: rms_n([delta(upper/lower quantile)]/sd) n={2,3,4}:'
    write(40,*) 'i.e. mean sample splitting change in the quantiles in units of the st. dev.'
    write (40,*) ''
    do j = 3, ncols
        if (isused(j)) then
            do endb =0,1
                if (endb==0 .and. has_limits_top(j))cycle
                if (endb==1 .and. has_limits_bot(j))cycle
                do split_n = 2,max_split_tests
                    call GetFractionIndices(frac,split_n)
                    split_tests(split_n) = 0
                    confid =  ConfidVal(j,(1-contours(num_contours))/2,endb==0,0,nrows-1)
                    do i=1,split_n

                    split_tests(split_n) = split_tests(split_n) + &
                    (ConfidVal(j,(1-contours(num_contours))/2,endb==0,frac(i),frac(i+1)-1)-confid)**2

                    end do !i
                    split_tests(split_n) = sqrt(split_tests(split_n)/split_n/fullvar(j))
                end do
                if (endb==0) then
                    typestr = 'upper'
                else
                    typestr = 'lower'
                end if
                write (40,'(1I3,'//trim(IntToStr(max_split_tests-1)) // 'f9.4,"  ' &
                //trim(labels(j))//' '//trim(typestr)//'")') j-2, split_tests(2:max_split_tests)

            end do !endb
        end if
    end do

    ! Now do Raftery and Lewis method
    ! See http://www.stat.washington.edu/tech.reports/raftery-lewis2.ps
    ! Raw non-importance sampled chains only
    if (all(abs(coldata(1,0:nrows-1) - nint(max(0.6_gp,coldata(1,0:nrows-1))))<1e-4)) then
        nburn = 0
        do ix=1, num_chains_used
            thin_fac(ix) = nint(maxval(coldata(1,chain_indices(ix):chain_indices(ix+1)-1)))

            do j = 3, covmat_dimension+2
                if (isused(j) .and. (force_twotail .or. .not. has_limits(j))) then
                    do endb =0,1
                        !Get binary chain depending on whether above or below confidence value
                        u = ConfidVal(j,(1-contours(num_contours))/2,endb==0,&
                        chain_indices(ix),chain_indices(ix+1)-1)
                        do !thin_fac
                            call ThinData(thin_fac(ix),chain_indices(ix),chain_indices(ix+1)-1)
                            if (thin_rows < 2) exit
                            allocate(binchain(0:thin_rows-1))
                            where (coldata(j,thin_ix(0:thin_rows-1)) >= u)
                                binchain = 1
                            elsewhere
                                binchain = 2
                            endwhere
                            tran = 0
                            !Estimate transitions probabilities for 2nd order process
                            do i = 2, thin_rows-1
                                tran(binchain(i-2),binchain(i-1),binchain(i)) = &
                                tran(binchain(i-2),binchain(i-1),binchain(i)) +1
                            end do 
                            deallocate(binchain)

                            !Test whether 2nd order is better than Markov using BIC statistic
                            g2 = 0
                            do i1=1,2
                                do i2=1,2
                                    do i3=1,2
                                        if (tran(i1,i2,i3)/=0) then
                                            fitted = dble(tran(i1,i2,1) + tran(i1,i2,2)) * &
                                            (tran(1,i2,i3) + tran(2,i2,i3))  / dble( tran(1,i2,1) + &
                                            tran(1,i2,2) + tran(2,i2,1) + tran(2,i2,2) )
                                            focus = dble( tran(i1,i2,i3) )
                                            g2 = g2 + log( focus / fitted ) * focus

                                        end if
                                    end do !i1
                                end do !i2
                            end do !i3
                            g2 = g2 * 2
                            if (g2 - log( dble(thin_rows-2) ) * 2 < 0) exit
                            thin_fac(ix) = thin_fac(ix) + 1
                        end do !thin_fac

                        !Get Markov transition probabilities for binary processes
                        if (sum(tran(:,1,2))==0 .or. sum(tran(:,2,1))==0) then
                            thin_fac(ix) = 0
                            goto 203
                        end if
                        alpha = sum(tran(:,1,2))/dble(sum(tran(:,1,1))+sum(tran(:,1,2)))
                        beta =  sum(tran(:,2,1))/dble(sum(tran(:,2,1))+sum(tran(:,2,2)))
                        probsum = alpha + beta
                        tmp1 = log(probsum * epsilon / max(alpha,beta))/ log( dabs(1.0d0 - probsum) )
                        if (int( tmp1 + 1 ) * thin_fac(ix) > nburn(ix)) then
                            nburn(ix) = int( tmp1 + 1 ) * thin_fac(ix)
                            hardest = j
                            hardestend = endb
                        end if
                    end do
                end if
            end do !j

            markov_thin(ix) = thin_fac(ix)

            !Get thin factor to have independent samples rather than Markov
            hardest = max(hardest,1)
            u = ConfidVal(hardest,(1-contours(num_contours))/2,hardestend==0)
            thin_fac(ix) = thin_fac(ix) + 1
            do !thin_fac
                call ThinData(thin_fac(ix),chain_indices(ix),chain_indices(ix+1)-1)
                if (thin_rows < 2) exit
                allocate(binchain(0:thin_rows-1))
                where (coldata(hardest,thin_ix(0:thin_rows-1)) > u)
                    binchain = 1
                elsewhere
                    binchain = 2
                endwhere
                tran2 = 0
                !Estimate transitions probabilities for 2nd order process
                do i = 1, thin_rows-1
                    tran2(binchain(i-1),binchain(i)) = &
                    tran2(binchain(i-1),binchain(i)) +1
                end do 
                deallocate(binchain)

                !Test whether independence is better than Markov using BIC statistic
                g2 = 0
                do i1=1,2
                    do i2=1,2
                        if (tran2(i1,i2)/=0) then
                            fitted = dble( (tran2(i1,1) + tran2(i1,2)) * (tran2(1,i2) + &
                            tran2(2,i2)) ) / dble(thin_rows -1)
                            focus = dble( tran2(i1,i2) )
                            if (fitted <= 0 .or. focus <= 0) then
                                write (*,*) 'Raftery and Lewis estimator had problems'
                                return
                            end if
                            g2 = g2 + dlog( focus / fitted ) * focus
                        end if
                    end do !i1
                end do !i2
                g2 = g2 * 2

                if (g2 - log( dble(thin_rows-1) ) < 0) exit
                thin_fac(ix) = thin_fac(ix) + 1
            end do !thin_fac

203         if (thin_rows < 2) thin_fac(ix) = 0

        end do !chains

        write (40,*) ''
        write (40,*) 'Raftery&Lewis statistics'
        write (40,*) ''
        write (40,*) 'chain  markov_thin  indep_thin    nburn'
        do ix = 1, num_chains_used
            if (thin_fac(ix)==0) then
                write (40,'(1I4,"      Not enough samples")') chain_numbers(ix)
            else
                write (40,'(1I4,3I12)') chain_numbers(ix), markov_thin(ix), &
                thin_fac(ix), nburn(ix)
            end if
        end do

        if (any(thin_fac(1:num_chains_used)==0)) then
            write (*,*) 'RL: Not enough samples to estimate convergence stats'
        else
            call writeS('RL: Thin for Markov:         '//&
            Trim(IntToStr(maxval(markov_thin(1:num_chains_used)))))
            indep_thin = maxval(thin_fac(1:num_chains_used))
            call writeS('RL: Thin for indep samples:  '// &
            trim(IntToStr(indep_thin)))
            call WriteS('RL: Estimated burn in steps: '//&
            trim(IntToStr(maxval(nburn(1:num_chains_used))))//' ('//&
            trim(IntToStr(nint(maxval(nburn(1:num_chains_used))/mean_mult)))//' rows)')

        end if

        !!Get correlation lengths
        write (40,*) ''
        write (40,*) 'Parameter auto-correlations as function of step separation'
        write (40,*) ''
        if (indep_thin ==0) then
            autocorr_thin = 20
        elseif (indep_thin <= 30) then
            autocorr_thin =  5
        else
            autocorr_thin = 5* (indep_thin/30)
        end if

        call ThinData(autocorr_thin,0,nrows-1)
        maxoff = min(15,thin_rows/(autocorr_thin*num_chains_used))
        allocate(Corrs(ncols,maxoff))
        corrs = 0
        do off =1,maxoff 
            do i=off, thin_rows-1
                do j = 3, ncols
                    if (isused(j)) &
                    corrs(j,off) = corrs(j,off) + (coldata(j,thin_ix(i))-fullmean(j))* &
                    (coldata(j,thin_ix(i-off)) - fullmean(j))
                end do
            end do
            do j = 3, ncols
                if (isused(j)) &
                corrs(j,off) = corrs(j,off)/(thin_rows-off)/fullvar(j)
            end do

        end do

        write (40,'("   ",'//trim(IntToStr(maxoff)) // 'I8)')  &
        (/(I, I=autocorr_thin, maxoff*autocorr_thin,autocorr_thin)/)

        do j = 3, ncols
            if (isused(j)) then        
                write (40,'(1I3,'//trim(IntToStr(maxoff)) // 'f8.3,"  ' &
                //trim(labels(j))//'")') j-2, corrs(j,:)
            end if
        end do

        deallocate(Corrs)

    end if

    close(40)

    end subroutine DoConvergeTests


    subroutine Get2DPlotData(j,j2)
    integer, intent(in) :: j,j2
    integer i,ix1,ix2
    real(mcp) norm, maxbin
    real(mcp) try_b, try_t,try_sum, try_last
    character(LEN=Ini_max_string_len) :: plotfile, filename,numstr
    real(mcp), dimension(:,:), allocatable :: finebins, finebinlikes, Win
    integer :: fine_fac = 5
    real(mcp) widthj,widthj2, contour_levels(max_contours)
    integer imin,imax,jmin,jmax

    bins2D = 0
    bin2Dlikes = 0
    bin2Dmax = 1e30_mcp

    if (smoothing) then
        imin = (ix_min(j)-3)*fine_fac+1
        imax = (ix_max(j)+3)*fine_fac-1
        jmin = (ix_min(j2)-3)*fine_fac+1
        jmax = (ix_max(j2)+3)*fine_fac-1
        allocate(finebins(imin:imax,jmin:jmax))
        allocate(finebinlikes(imin:imax,jmin:jmax))
        finebins = 0
        finebinlikes=0

        widthj = width(j)/fine_fac
        widthj2 = width(j2)/fine_fac
        do i = 0, nrows-1
            ix1=nint((coldata(colix(j),i)-center(j))/widthj)
            ix2=nint((coldata(colix(j2),i)-center(j2))/widthj2)
            if (ix1>=imin .and. ix1<=imax .and. ix2>=jmin .and. ix2 <=jmax) then
                finebins(ix1,ix2) = finebins(ix1,ix2) + coldata(1,i)
                finebinlikes(ix1,ix2) = finebinlikes(ix1,ix2) + coldata(1,i)*exp(meanlike - coldata(2,i))

                ix1=nint((coldata(colix(j),i)-center(j))/width(j))
                ix2=nint((coldata(colix(j2),i)-center(j2))/width(j2))
                bin2Dmax(ix1,ix2) = min(bin2Dmax(ix1,ix2),real(coldata(2,i),mcp))
            end if
        end do

        allocate(Win(-2*fine_fac:2*fine_fac,-2*fine_fac:2*fine_fac))

        do ix1=-2*fine_fac,2*fine_fac
            do ix2=-2*fine_fac,2*fine_fac
                Win(ix1,ix2) = exp(-(ix1**2+ix2**2)/real(fine_fac**2,mcp)/2)
            end do
        end do
        do ix1=ix_min(j), ix_max(j)
            do ix2=ix_min(j2),ix_max(j2)
                bins2D(ix1,ix2) = sum(win* finebins(ix1*fine_fac-2*fine_fac:ix1*fine_fac+2*fine_fac, &
                ix2*fine_fac-2*fine_fac:ix2*fine_fac+2*fine_fac ))
                bin2Dlikes(ix1,ix2)= sum(win* finebinlikes(ix1*fine_fac-2*fine_fac:ix1*fine_fac+2*fine_fac, &
                ix2*fine_fac-2*fine_fac:ix2*fine_fac+2*fine_fac ))
            end do
        end do

        deallocate(Win,finebins,finebinlikes)

    else

    !no smoothing
    do i = 0, nrows-1
        ix1=nint((coldata(colix(j),i)-center(j))/width(j))
        ix2=nint((coldata(colix(j2),i)-center(j2))/width(j2))
        bins2D(ix1,ix2) = bins2D(ix1,ix2) + coldata(1,i)
        bin2Dlikes(ix1,ix2) = bin2Dlikes(ix1,ix2) + coldata(1,i)*exp(meanlike-coldata(2,i))
        bin2Dmax(ix1,ix2) = min(bin2Dmax(ix1,ix2),real(coldata(2,i)))
    end do

    end if

    do ix1=ix_min(j),ix_max(j)
        do ix2 =ix_min(j2),ix_max(j2)
            if (bins2D(ix1,ix2) >0) bin2Dlikes(ix1,ix2) = bin2Dlikes(ix1,ix2)/bins2D(ix1,ix2)
            if (plot_NDcontours) then
                !Map maximum likelihood in each bin into a significance value from the full N-D distribution
                if (bin2DMax(ix1,ix2) == 1e30_mcp) then
                    bin2DMax(ix1,ix2) = 0
                else
                    bin2DMax(ix1,ix2) = sum(coldata(1,0:nrows-1), mask = coldata(2,0:nrows-1) > bin2DMax(ix1,ix2))/numsamp
                end if
            end if
        end do
    end do


    if (has_limits(colix(j)) .or. has_limits(colix(j2))) then

    !Fix up underweighting near edges. Note this makes edge pixels noisier.
    do ix1 = ix_min(j), ix_max(j)
        do ix2 = ix_min(j2),ix_max(j2)
            if (ix1 ==ix_min(j) .and. has_limits_bot(colix(j))) bins2D(ix1,ix2) = bins2D(ix1,ix2)*2
            if (ix1 ==ix_max(j) .and. has_limits_top(colix(j))) bins2D(ix1,ix2) = bins2D(ix1,ix2)*2
            if (ix2 ==ix_min(j2).and. has_limits_bot(colix(j2))) bins2D(ix1,ix2) = bins2D(ix1,ix2)*2
            if (ix2 ==ix_max(j2).and. has_limits_top(colix(j2))) bins2D(ix1,ix2) = bins2D(ix1,ix2)*2
            if (smoothing) then !!Aug 2006
                if (ix1 ==ix_min(j)+1.and. has_limits_bot(colix(j))) bins2D(ix1,ix2) = bins2D(ix1,ix2)/0.84
                if (ix1 ==ix_max(j)-1.and. has_limits_top(colix(j))) bins2D(ix1,ix2) = bins2D(ix1,ix2)/0.84
                if (ix2 ==ix_min(j2)+1.and. has_limits_bot(colix(j2))) bins2D(ix1,ix2) = bins2D(ix1,ix2)/0.84
                if (ix2 ==ix_max(j2)-1.and. has_limits_top(colix(j2))) bins2D(ix1,ix2) = bins2D(ix1,ix2)/0.84
            end if 
        end do
    end do

    end if

    ! Get contour containing contours(:) of the probability

    allocate(TheBins(ix_max(j)-ix_min(j)+1,ix_max(j2)-ix_min(j2)+1))
    TheBins = bins2D(ix_min(j):ix_max(j),ix_min(j2):ix_max(j2))

    norm = sum(TheBins)

    do ix1 = 1, num_contours
        try_t = maxval(TheBins)
        try_b = 0
        try_last = -1
        do
            try_sum = sum(TheBins,mask = TheBins < (try_b + try_t)/2)
            if (try_sum > (1-contours(ix1))*norm) then
                try_t = (try_b+try_t)/2
            else
                try_b = (try_b+try_t)/2
            end if
            if (try_sum == try_last) exit
            try_last = try_sum

        end do
        contour_levels(ix1) = (try_b+try_t)/2

    end do
    deallocate(TheBins)


    plotfile = dat_file_2D(rootname, j, j2)
    filename = trim(plot_data_dir)//trim(plotfile)
    open(unit=49,file=filename,form='formatted',status='replace')
    do ix1 = ix_min(j), ix_max(j)
        write (49,trim(numcat('(',ix_max(j2)-ix_min(j2)+1))//'E16.7)') bins2D(ix1,ix_min(j2):ix_max(j2))
    end do
    close(49)

    open(unit=49,file=trim(filename)//'_cont',form='formatted',status='replace')
    write(numstr,*) contour_levels(1:num_contours)
    if (num_contours==1) numstr = trim(numstr)//' '//trim(numstr)
    write (49,*) trim(numstr)
    close(49)

    if (shade_meanlikes) then
        open(unit=49,file=trim(filename)//'_likes',form='formatted',status='replace')
        maxbin = maxval(bin2Dlikes(ix_min(j):ix_max(j),ix_min(j2):ix_max(j2)))
        do ix1 = ix_min(j), ix_max(j)
            write (49,trim(numcat('(',ix_max(j2)-ix_min(j2)+1))//'E16.7)') &
            bin2Dlikes(ix1,ix_min(j2):ix_max(j2))/maxbin
        end do
        close(49)
    end if

    if (plot_NDcontours) then
        open(unit=49,file=trim(filename)//'_confid',form='formatted',status='replace')
        do ix1 = ix_min(j), ix_max(j)
            write (49,trim(numcat('(',ix_max(j2)-ix_min(j2)+1))//'E16.7)') &
            bin2Dmax(ix1,ix_min(j2):ix_max(j2))

        end do
        close(49)
    end if

    end subroutine Get2DPlotData

    function PlotContMATLAB(aunit,aroot,j,j2, DoShade)
    character(LEN=*), intent(in) :: aroot
    integer, intent(in) :: j, j2,aunit
    logical, intent(in) :: DoShade
    character(LEN=Ini_max_string_len) fname,numstr,plotfile
    logical PlotContMATLAB

    PlotContMATLAB= .false.
    plotfile = dat_file_2D(aroot, j, j2)
    if (.not. FileExists(trim(plot_data_dir)//trim(plotfile))) return
    PlotContMATLAB= .true.
    write (aunit,'(a)') "pts=load(fullfile(plotdir,'" // trim(plotfile) //"'));"

    fname = dat_file_name(aroot, j2)
    write (aunit,'(a)') "tmp = load(fullfile(plotdir,'" // trim(fname)//  '.dat''));'
    write (aunit,*) 'x1 = tmp(:,1);'

    fname = dat_file_name(aroot, j)
    write (aunit,'(a)') "tmp = load(fullfile(plotdir,'" // trim(fname)//  '.dat''));'
    write (aunit,*) 'x2 = tmp(:,1);'
    if (DoShade) then
        if (shade_meanlikes) then
            write (aunit,'(a)') "ptsL=load(fullfile(plotdir,'" // trim(plotfile) //'_likes''));'
            write (aunit,'(a)') 'contourf(x1,x2,ptsL,64);'
        else
            write (aunit,*) 'contourf(x1,x2,pts,64);'
        end if

        write (aunit,*) 'set(gca,''climmode'',''manual''); shading flat; hold on;'
    end if

    if (num_contours /= 0) then
        write (aunit,'(a)') "cnt = load(fullfile(plotdir,'" // trim(plotfile) //'_cont''));'

        if (plot_NDcontours) then
            write (aunit,'(a)') "ptND=load(fullfile(plotdir,'" // trim(plotfile) //'_confid''));'
            write(numstr,*) 1-contours(1:num_contours)
            if (num_contours==1) numstr = trim(numstr)//' '//trim(numstr)
            write (aunit,'(a)') 'contour(x1,x2,ptND,['//trim(numstr)//'],''r'');'
        end if
    end if

    end function PlotContMATLAB

    function matlabLabel(i)
    integer, intent(in) :: i
    character(LEN=120) matlabLabel

    if (matlab_latex) then
        matlabLabel = '$$'//trim(labels(i))//'$$'
    else
        matlabLabel= labels(i)
    end if
    end function matlabLabel

    subroutine Write2DPlotMATLAB(aunit,j,j2, DoLabelx,DoLabely, hide_ticklabels)
    integer, intent(in) :: aunit,j,j2
    logical, intent(in) :: DoLabelx,DoLabely
    logical, intent(in), optional :: hide_ticklabels
    character(LEN=120) fmt
    integer i
    logical hide_ticks

    if (present(hide_ticklabels)) then
        hide_ticks = hide_ticklabels
    else
        hide_ticks = .false.
    endif

    if (PlotContMATLAB(aunit,rootname,j,j2,do_shading) .and. &
    num_contours /= 0) then

    write (aunit,'(a)') '[C h] = contour(x1,x2,pts,cnt,lineM{1});'
    write (aunit,'(a)') 'set(h,''LineWidth'',lw1);'
    write (aunit,*) 'hold on; axis manual; '

    do i = 1, Num_ComparePlots
        fmt = trim(numcat('lineM{',i+1)) // '}'
        if (PlotContMATLAB(aunit,ComparePlots(i),j,j2,.false.)) &
        write (aunit,'(a)') '[C h] = contour(x1,x2,pts,cnt,'//trim(fmt)//');'
        write (aunit,'(a)') 'set(h,''LineWidth'',lw2);'

    end do

    end if

    write (aunit,'(a)') 'hold off; set(gca,''Layer'',''top'',''FontSize'',axes_fontsize);'
    fmt = ''',''FontSize'',lab_fontsize);'
    if (DoLabelx) then
        write (aunit,'(a)') 'xlabel('''//trim(matlabLabel(colix(j2)))//trim(fmt)
    else
        if (hide_ticks) write(aunit,*) 'set(gca,''xticklabel'',[]);'
    end if
    if (DoLabely) then
        write (aunit,'(a)') 'ylabel('''//trim(matlabLabel(colix(j)))//trim(fmt)
    else
        if (hide_ticks) write(aunit,*) 'set(gca,''yticklabel'',[]);'
    end if
    end subroutine  Write2DPlotMATLAB


    subroutine WriteMatLabInit(unit,sm, subplot_size)
    integer, intent(in) :: unit
    logical, intent(in) :: sm
    real, intent(in) :: subplot_size
    integer sz

    write(unit,*) 'plot_size_inch = '//trim(RealToStr(subplot_size))//';'
    write(unit,'(a)') 'plotdir='''//trim(plot_data_dir)//''';'
    write(unit,'(a)') 'outdir='''//trim(out_dir)//''';'
    sz = 12
    if (sm .and. subplot_size < 4) sz=9
    sz = nint(sz*font_scale)
    write(unit,*) trim(concat('lab_fontsize = ',sz,'; axes_fontsize = ',sz,';'))
    if (matlab_latex) write(unit,*) 'set(0,''DefaultTextInterpreter'',''Latex'');'
    write(unit,*) 'clf'
    if (BW) then
        if (plot_meanlikes) then
            write(unit,*) 'lineM = {''-k'',''-r'',''-b'',''-m'',''-g'',''-c'',''-y''};';
            write(unit,*) 'lineL = {'':k'','':r'','':b'','':m'','':g'','':c'','':y''};';
            write(unit,*) 'lw1=3;lw2=1;' !Line Widths
        else
            write(unit,*) 'lineM = {''-k'',''--r'',''-.b'','':m'',''--g'',''-.c'',''-y''};';
            write(unit,*) 'lw1=1;lw2=1;' !Line Widths
        end if
    else
        write(unit,*) 'lineM = {''-k'',''-r'',''-b'',''-m'',''-g'',''-c'',''-y'',''--k'',''--r'',''--b''};';
        write(unit,*) 'lineL = {'':k'','':r'','':b'','':m'','':g'','':c'','':y'',''-.k'',''-.r'',''-.b''};';
        write(unit,*) 'lw1=1;lw2=1;' !Line Widths
    end if
    write(unit,*) 'colstr=''krbmgcykrb'';'

    end subroutine WriteMatLabInit

    subroutine WriteMatLabPrint(unit, tag, plot_col, plot_row)
    integer, intent(in) :: unit, plot_col, plot_row
    character(LEN=*), intent(in) :: tag
    character(LEN=10) command

    write(unit,*)  'set(gcf, ''PaperUnits'',''inches'');'
    write(unit,*) 'x=',plot_col,'*plot_size_inch; y=',plot_row,'*plot_size_inch;'
    write(unit,*) 'set(gcf, ''PaperPosition'',[0 0 x y]); set(gcf, ''PaperSize'',[x y]);'
    if (matlab_plot_output == 'ps')  command='-dpsc2'
    if (matlab_plot_output == 'pdf')  command='-dpdf'
    if (matlab_plot_output == 'eps') command='-depsc2'
    write (unit,'(a)') 'print('''//trim(command)//''',fullfile(outdir,''' &
    // trim(rootname)//trim(tag)//'.'//trim(matlab_plot_output)//'''));'

    end subroutine WriteMatLabPrint

    subroutine Write1DplotMatLab(aunit,j)
    integer, intent(in) :: aunit, j
    character(LEN=Ini_max_string_len) fname
    character(LEN=60) fmt
    integer ix1

    fname = dat_file_name(rootname, j)
    write (aunit,'(a)') "pts=load(fullfile(plotdir,'" // trim(fname)//  '.dat''));'
    write (aunit,*) 'plot(pts(:,1),pts(:,2),lineM{1},''LineWidth'',lw1);'
    write (aunit,*) 'axis([-Inf,Inf,0,1.1]);axis manual;'
    write (aunit,*) 'set(gca,''FontSize'',axes_fontsize); hold on;'

    if (plot_meanlikes) then
        write (aunit,'(a)') "pts=load(fullfile(plotdir,'" // trim(fname)//  '.likes''));'
        write (aunit,*) 'plot(pts(:,1),pts(:,2),lineL{1},''LineWidth'',lw1);'
    end if

    if (has_markers(colix(j))) then
        write (aunit,'("line([",1e15.6," ",1e15.6,"],[0 2],''Color'',''k'');")') markers(colix(j)),markers(colix(j))
    end if

    do ix1 = 1, Num_ComparePlots
        fname = dat_file_name(ComparePlots(ix1),j)
        if (FileExists(trim(plot_data_dir)// trim(fname)//'.dat')) then

        write (aunit,'(a)') "pts = load(fullfile(plotdir,'" // trim(fname)// '.dat''));'
        fmt = trim(numcat('lineM{',ix1+1)) // '}'
        write (aunit,'(a)') 'plot(pts(:,1),pts(:,2),'//trim(fmt)//',''LineWidth'',lw2);'

        if (plot_meanlikes) then

        write (aunit,'(a)') "pts=load(fullfile(plotdir,'" //trim(fname)//'.likes''));'
        fmt = trim(numcat('lineL{',ix1+1)) // '}'
        write (aunit,'(a)') 'plot(pts(:,1),pts(:,2),'//trim(fmt)//',''LineWidth'',lw2);'

        end if

        end if
    end do

    end subroutine Write1DplotMatLab

    subroutine WriteMatlabLineLabels(aunit)
    integer, intent(in) :: aunit
    integer ix1
    call WriteFormatInts(aunit,'set(gcf,''Units'',''Normal''); frac=1/%u;',Num_ComparePlots+1)
    write(aunit,'(a)') 'ax=axes(''Units'',''Normal'',''Position'',[0.1,0.95,0.85,0.05],''Visible'',''off'');'
    write(aunit,'(a)') 'text(0,0,'''//trim(rootname)//''',''color'', colstr(1),''Interpreter'',''none'');'
    do ix1 = 1, Num_ComparePlots
        call WriteFormatInts(aunit, 'text(frac*%u,0,''' //trim(ComparePlots(ix1)) // &
        ''',''Interpreter'',''none'',''color'',colstr(%u));', ix1, ix1+1)
    end do

    end  subroutine WriteMatlabLineLabels

    subroutine EdgeWarning(param)
    integer, intent(in) :: param

    if (NameMapping%nnames==0 .or. ParamNames_name(NameMapping,param)=='') then
        call WriteS('Warning: sharp edge in parameter '//trim(intToStr(param))// &
        ' - check limits'//trim(intToStr(param)))
    else
        call WriteS('Warning: sharp edge in parameter '//trim(ParamNames_name(NameMapping,param))// &
        ' - check limits['//trim(ParamNames_name(NameMapping,param))//'] or limits'//trim(intToStr(param)))

    end if

    end subroutine EdgeWarning

    function dat_file_name(rootname,j)
    integer, intent(in) :: j
    character(LEN=*) :: rootname
    character(LEN= Ini_max_string_len) :: dat_file_name
    dat_file_name =  trim(rootname)//'_p_'//trim(ParamNames_NameOrNumber(NameMapping, colix(j)-2))
    end function dat_file_name

    function dat_file_2D(rootname,j, j2)
    integer, intent(in) :: j, j2
    character(LEN=*) :: rootname
    character(LEN= Ini_max_string_len) :: dat_file_2D
    dat_file_2D =  trim(rootname)//'_2D_'//trim(ParamNames_NameOrNumber(NameMapping, colix(j)-2)) &
    //'_'//trim(ParamNames_NameOrNumber(NameMapping, colix(j2)-2))
    end function dat_file_2D

    end module MCSamples

    subroutine CheckMatlabAxes(afile)
    integer, intent(in) :: afile

    write (afile,*) 'ls =get(gca,''XTick'');sz=size(ls,2);'
    write (afile,*) 'if(sz>2 && abs(ls(sz)-ls(1))<0.01)'
    write (afile,*) ' set(gca,''XTick'',ls(:,1:round(sz/2):sz));'
    write (afile,*) 'elseif (sz>4)'
    write (afile,*) ' set(gca,''XTick'',ls(:,1:2:sz));'
    write (afile,*) 'end;'

    end subroutine CheckMatlabAxes


    program GetDist
    use IniFile
    use MCSamples
    use IO
    implicit none

    real(mcp)  bincounts(-1000:1000),binlikes(-1000:1000),binmaxlikes(-1000:1000), &
    binsraw(-1000:1000)

    character(LEN=Ini_max_string_len) InputFile, numstr
    character(LEN=Ini_max_string_len) fname, parameter_names_file, &
    parameter_names_labels
    character(LEN=10000) InLine  ! ,LastL,OutLine
    integer ix, ix1,i,ix2,ix3, nbins, wx
    real(mcp) ignorerows

    logical bad, adjust_priors

    real(mcp)  amax, amin
    character(LEN=Ini_max_string_len) filename, infile, out_root
    character(LEN=120) matlab_col, InS1,InS2,fmt
    integer plot_row, plot_col, chain_num, first_chain,chain_ix, plot_num

    integer x,y,j,j2, i2, num_2D_plots, num_cust2D_plots
    integer num_3D_plots
    character(LEN=80) contours_str, plot_3D(20), bin_limits
    integer thin_factor, outliers
    real(mcp) limmin(max_cols),limmax(max_cols), maxbin
    integer plot_2D_param, j2min
    real(mcp) try_b, try_t, binweight
    real(mcp) cont_lines(max_cols,2,max_contours), dist, distweight, limfrac
    real(mcp) :: minimal_intervals(max_cols,max_intersections+1,max_contours) !JH
    logical do_minimal_1d_intervals !JH

    integer bestfit_ix
    integer chain_exclude(max_chains), num_exclude
    logical map_params
    logical :: triangle_plot = .false.
    logical :: no_triangle_axis_labels = .false.
    real(mcp) counts
    real(mcp) cool
    integer PCA_num, PCA_normparam
    integer PCA_params(max_cols)
    integer plotparams_num, plotparams(max_cols)
    character(LEN=max_cols) PCA_func
    logical Done2D(max_cols,max_cols)
    logical no_plots, line_labels

    real(mcp) thin_cool
    logical no_tests, auto_label

    logical :: single_column_chain_files, samples_are_chains
    !for single_colum_chain_files
    integer :: first_haschain, stat, ip, itmp, idx, nrows2(max_cols), tmp_params(max_cols)
    real(mcp) :: rtmp
    character(LEN=Ini_max_string_len) :: finish_run_command
    integer chain_handle
    integer triangle_num, triangle_params(max_cols)

    NameMapping%nnames = 0

    InputFile = GetParam(1)
    if (InputFile == '') stop 'No parameter input file'

    call IO_Ini_Load(DefIni,InputFile, bad)

    if (bad) stop 'Error opening parameter file'

    parameter_names_file = Ini_Read_String('parameter_names')
    if (parameter_names_file/='') call ParamNames_Init(NameMapping,parameter_names_file)
    parameter_names_labels = Ini_Read_String('parameter_names_labels')
    matlab_latex = Ini_read_logical('matlab_latex',.false.)

    if (Ini_HasKey('nparams')) then
        ncols = Ini_Read_Int('nparams') + 2
        if (Ini_HasKey('columnnum')) stop 'specify only one of nparams or columnnum'
    else
        ncols = Ini_Read_Int('columnnum',0)
    end if

    if (NameMapping%nnames/=0 .and. ncols==0) then
        ncols = NameMapping%nnames+2
    end if

    Ini_fail_on_not_found = .true.

    in_root = Ini_Read_String('file_root')
    rootname = ExtractFileName(in_root)
    chain_num = Ini_Read_Int('chain_num')

    single_column_chain_files = Ini_Read_Logical( 'single_column_chain_files',.false.)

    if ( single_column_chain_files ) then

    pname(1) = 'weight'
    pname(2) = 'lnlike'
    Ini_fail_on_not_found = .false.
    do ix=3, ncols
        pname(ix) = Ini_Read_String(concat('pname',ix-2))
        if (pname(ix)=='' .and. NameMapping%nnames/=0) then
            pname(ix) = NameMapping%name(ix-2)
        end if
    end do
    Ini_fail_on_not_found = .true.

    else

    if (parameter_names_file=='') then
        call IO_ReadParamNames(NameMapping,in_root)
        if (ncols==0 .and. NameMapping%nnames/=0) ncols = NameMapping%nnames+2
    end if
    if (parameter_names_labels/='') &
    call ParamNames_SetLabels(NameMapping,parameter_names_labels)


    if (ncols==0) then
        if (chain_num == 0) then
            infile = trim(in_root) // '.txt'
        else
            infile = trim(in_root) //'_1.txt'
        end if

        ncols = TxtFileColumns(infile)
        write (*,*) 'Reading ',ncols, 'columns'
    end if

    end if

    allocate(coldata(ncols,0:max_rows))

    nbins = Ini_Read_Int('num_bins')

    ignorerows = Ini_Read_Double('ignore_rows',0.d0)

    adjust_priors = Ini_Read_Logical('adjust_priors',.false.)

    Ini_fail_on_not_found = .false.

    matlab_version = Ini_Read_Real('matlab_version',8.)
    matlab_plot_output = Ini_Read_String_Default('matlab_plot_output',matlab_plot_output)
    matlab_subplot_size_inch = Ini_Read_Real('matlab_subplot_size_inch', &
    matlab_subplot_size_inch)
    matlab_subplot_size_inch2 = Ini_Read_Real('matlab_subplot_size_inch2', &
    matlab_subplot_size_inch)
    matlab_subplot_size_inch3 = Ini_Read_Real('matlab_subplot_size_inch3', &
    matlab_subplot_size_inch)

    font_scale  = Ini_Read_Real('font_scale',1.)
    finish_run_command = Ini_Read_String('finish_run_command')

    labels(1) = 'mult'
    labels(2) = 'likelihood'
    auto_label = Ini_Read_Logical('auto_label',.false.)
    do ix=3, ncols
        if (auto_label) then
            write (numstr,*) ix-2
            labels(ix) = trim(adjustl(numstr))
        else
            if (NameMapping%nnames/=0 .and. .not. &
            ParamNames_HasReadIniForParam(NameMapping,DefIni, 'lab',ix-2)) then

            labels(ix) = trim(NameMapping%label(ix-2))

            else
                labels(ix) = ParamNames_ReadIniForParam(NameMapping,DefIni,'lab',ix-2)
            end if
            !Ini_Read_String('lab'//trim(adjustl(numstr)))
        end if
    end do

    prob_label = Ini_Read_Logical('prob_label',.false.)

    samples_are_chains = Ini_Read_Logical('samples_are_chains',.true.)

    no_plots = Ini_Read_Logical('no_plots',.false.)
    plots_only = Ini_Read_Logical('plots_only',.false.)
    no_tests = plots_only .or. Ini_Read_Logical('no_tests',.false.)
    line_labels = Ini_Read_Logical('line_labels',.false.)

    thin_factor = Ini_Read_Int('thin_factor',0)
    thin_cool = Ini_read_Real('thin_cool',1.)

    first_chain = Ini_Read_Int('first_chain',1)

    make_single_samples = Ini_Read_logical('make_single_samples',.false.)
    single_thin = Ini_Read_Int('single_thin',1)
    cool = Ini_Read_Real('cool',1.)

    Num_ComparePlots = Ini_Read_Int('compare_num',0)
    allocate(ComparePlots(num_comparePlots))
    do ix = 1, Num_ComparePlots
        ComparePlots(ix) = ExtractFileName(Ini_Read_String(numcat('compare',ix)))
    end do

    has_limits_top = .false.
    has_limits_bot = .false.

    bin_limits = Ini_Read_String('all_limits')
    markers=0
    has_markers=.false.
    do ix=3, ncols
        if (bin_limits /= '') then
            InLine = bin_limits
        else
            InLine = ParamNames_ReadIniForParam(NameMapping,DefIni,'limits',ix-2)
            !Ini_Read_String('limits'//trim(adjustl(numstr)))
        end if
        if (InLine /= '') then
            read (InLine,*) InS1, InS2
            if (trim(adjustl(InS1)) /= 'N') then
                has_limits_bot(ix) = .true.
                read(InS1,*) limmin(ix)
            end if
            if (trim(adjustl(InS2)) /= 'N') then
                has_limits_top(ix) = .true.
                read(InS2,*) limmax(ix)
            end if
        end if

        InLine = ParamNames_ReadIniForParam(NameMapping,DefIni,'marker',ix-2)
        if (InLine /= '') then
            has_markers(ix) = .true.
            read(InLine,*) markers(ix)
        end if

    end do

    has_limits = has_limits_top .or. has_limits_bot

    plotparams_num = Ini_Read_Int('plotparams_num',0)
    if (plotparams_num /= 0) then
        InLine = Ini_Read_String('plotparams')
        call ParamNames_ReadIndices(NameMapping,InLine, plotparams, plotparams_num)
    end if

    InLine = Ini_Read_String('plot_2D_param')
    if (InLine=='') then
        plot_2D_param = 0
    else
        call ParamNames_ReadIndices(NameMapping,InLine, tmp_params, 1)
        plot_2D_param = tmp_params(1)
        if (plot_2D_param/=0 .and. plotparams_num/=0 .and. &
        count(plotparams(1:plotparams_num)==plot_2D_param)==0) &
        stop 'plot_2D_param not in plotparams'
    end if

    if (plot_2D_param /= 0) then
        plot_2D_param = plot_2D_param + 2
        num_cust2D_plots = 0
    else
        !Use custom array of specific plots
        num_cust2D_plots = Ini_Read_Int('plot_2D_num',0)
        do ix = 1, num_cust2D_plots
            InLine = Ini_Read_String(numcat('plot',ix))
            call ParamNames_ReadIndices(NameMapping,InLine, tmp_params, 2)
            if (plotparams_num/=0 .and. (count(plotparams(1:plotparams_num)==tmp_params(1))==0 .or. &
            count(plotparams(1:plotparams_num)==tmp_params(2))==0)) then
                write(*,*) trim(numcat('plot',ix)) //': parameter not in plotparams'
                stop
            end if
            cust2DPLots(ix) = tmp_params(1)+2 + (tmp_params(2)+2)*1000
        end do
    end if

    triangle_plot = Ini_Read_Logical('triangle_plot',.false.)
    if (triangle_plot) then
        no_triangle_axis_labels = Ini_read_Logical('no_triangle_axis_labels',.false.)
        InLine = Ini_Read_String('triangle_params')
        triangle_num=-1
        if (InLine/='') then
            call ParamNames_ReadIndices(NameMapping,InLine, triangle_params, triangle_num, unknown_value=-1)
        end if
    end if


    InS1 =Ini_Read_String('exclude_chain')
    num_exclude = 0
    chain_exclude = 0
    read (InS1, *, end =20) chain_exclude

20  do while (chain_exclude(num_exclude+1)/=0)
        num_exclude = num_exclude + 1
    end do


    map_params = Ini_Read_Logical('map_params',.false.)
    if (map_params)  &
    write (*,*) 'WARNING: Mapping params - .covmat file is new params.'

    shade_meanlikes = Ini_Read_Logical('shade_meanlikes',.false.)

    matlab_col = Ini_Read_String('matlab_colscheme')
    smoothing = Ini_Read_Logical('smoothing',.true.)

    out_dir = Ini_Read_String('out_dir')

    out_root = Ini_Read_String('out_root')
    if (out_root /= '') then
        rootname = out_root
        write (*,*) 'producing files with with root '//trim(out_root)
    end if

    plot_data_dir = Ini_Read_String( 'plot_data_dir' )
    if ( plot_data_dir == '' ) then
        plot_data_dir = 'plot_data/'
    end if

    plot_data_dir = CheckTrailingSlash(plot_data_dir)

    if (out_dir /= '') then
        out_dir = CheckTrailingSlash(out_dir)
        write (*,*) 'producing files in directory '//trim(out_dir)
    end if

    rootdirname = concat(out_dir,rootname)

    num_contours = Ini_Read_Int('num_contours',2)
    contours_str = ''
    do i=1, num_contours
        contours(i) = Ini_Read_Real(numcat('contour',i))
        if (i>1) contours_str = concat(contours_str,'; ')
        contours_str = concat(contours_str, Ini_Read_String(numcat('contour',i)))
    end do

    force_twotail = Ini_Read_Logical('force_twotail',.false.)
    if (force_twotail) write (*,*) 'Computing two tail limits'

    if (Ini_Read_String('cov_matrix_dimension')=='') then
        if (NameMapping%nnames/=0) covmat_dimension = NameMapping%num_MCMC
    else
        covmat_dimension = Ini_Read_Int('cov_matrix_dimension',0)
        if (covmat_dimension == -1) covmat_dimension = ncols-2
    end if

    plot_meanlikes = Ini_Read_Logical('plot_meanlikes',.false.)
    plot_NDcontours = Ini_Read_Logical('plot_NDcontours',.false.)

    do_minimal_1d_intervals = Ini_Read_Logical('do_minimal_1d_intervals',.false.) !JH

    PCA_num = Ini_Read_Int('PCA_num',0)
    if (PCA_num /= 0) then
        if (PCA_num <2) stop 'Can only do PCA for 2 or more parameters'
        InLine = Ini_Read_String('PCA_params')
        PCA_func =Ini_Read_String('PCA_func')
        !Characters representing functional mapping
        if (PCA_func == '') PCA_func(1:PCA_num) = 'N' !no mapping
        if (InLine == 'ALL' .or. InLine == 'all') then
            PCA_params(1:PCA_num) = (/ (i, i=1,PCA_num)/)
        else
            call ParamNames_ReadIndices(NameMapping,InLine, PCA_params, PCA_num)
        end if
        InLIne = Ini_Read_String('PCA_normparam')
        if (InLine=='') then
            PCA_NormParam = 0
        else
            call ParamNames_ReadIndices(NameMapping,InLine, tmp_params, 1)
            PCA_NormParam = tmp_params(1)
        end if

    end if


    num_3D_plots = Ini_Read_Int('num_3D_plots',0)
    do ix =1, num_3D_plots
        plot_3D(ix) = Ini_Read_String(numcat('3D_plot',ix))
    end do

    BW = Ini_Read_Logical('B&W',.false.)
    do_shading = Ini_Read_Logical('do_shading',.true.)
    call Ini_Close

    allocate(bins2D(-1000:1000,-1000:1000),bin2Dlikes(-1000:1000,-1000:1000),bin2Dmax(-1000:1000,-1000:1000))


    !Read in the chains
    nrows = 0
    num_chains_used =0

    do chain_ix = first_chain, first_chain-1 + max(1,chain_num)

    if (any(chain_exclude(1:num_exclude)==chain_ix)) cycle

    num_chains_used = num_chains_used + 1
    if (num_chains_used > max_chains) stop 'Increase max_chains in GetDist'
    chain_indices(num_chains_used) = nrows
    chain_numbers(num_chains_used) = chain_ix

    if ( single_column_chain_files ) then
        !Use used for WMAP 5-year chains suppled on LAMBDA; code from Mike Nolta
        !Standard CosmoMC case below

        first_haschain=0
        do ip = 1,ncols
            infile = concat(CheckTrailingSlash(concat(in_root,chain_ix)), pname(ip))
            if (.not. FileExists(infile)) then
                write (*,'(a)') 'skipping missing ' // trim(infile)
                coldata(ip,:) = 0
                nrows2(ip) = -1
            else

            write (*,'(a)') 'reading ' // trim(infile)
            ! call OpenTxtFile(infile,50)
            chain_handle = IO_OpenChainForRead(infile)
            if (first_haschain==0) first_haschain=ip
            nrows2(ip) = 0
            idx = 0 !Jo -1
            do
                read (chain_handle,'(a)',iostat=stat) InLine
                if ( stat /= 0 ) exit
                idx = idx + 1

                if ( ignorerows >= 1 .and. idx <= nint(ignorerows) ) then
                    print *, 'ignoring row'
                    cycle
                end if

                if (SCAN (InLine, 'N') /=0) then
                    write (*,*) 'WARNING: skipping line with probable NaN'
                    cycle
                end if

                read(InLine,*,iostat=stat) itmp, rtmp
                if ( stat /= 0 ) then
                    write (*,*) 'error reading line ', nrows2(ip) + int(ignorerows), ' - skipping rest of file'
                    exit
                end if
                if ( idx /= itmp ) then
                    print *, "*** out of sync", idx, itmp
                    stop
                end if

                coldata(ip,nrows2(ip)) = rtmp
                nrows2(ip) = nrows2(ip) + 1
                if (nrows2(ip) > max_rows) stop 'need to increase max_rows'

            end do
            call IO_Close(chain_handle)
            end if
        end do
        if (first_haschain==0) stop 'no chain parameter files read!'
        do ip = 2,ncols
            if ( nrows2(ip)/=-1 .and. nrows2(ip) /= nrows2(first_haschain) ) then
                print *, '*** nrows mismatch:'
                print *, nrows2(1:ncols)
                stop
            end if
        end do
        nrows = nrows2(first_haschain)
        print *, 'all columns match, nrows = ', nrows

    else  !Not single column chain files (usual cosmomc format)

    !This increments nrows by number read in
    if (.not. IO_ReadChainRows(in_root, chain_ix, chain_num, int(ignorerows),nrows,ncols,max_rows, &
    coldata,samples_are_chains)) then
        num_chains_used = num_chains_used - 1
        cycle
    endif

    end if

    if (map_params) then
        do ip =chain_indices(num_chains_used),nrows-1
            call MapParameters(coldata(1:ncols, ip))
        end do
    end if

    if (ignorerows<1 .and. ignorerows/=0) then
        i = chain_indices(num_chains_used)
        j = nint((nrows-i-1)*ignorerows)
        do ix = i,nrows-j-1
            coldata(:,ix) = coldata(:,ix+j)
        end do
        nrows = nrows - j
    end if

    end do

    if (nrows == 0) stop 'No un-ignored rows! (check number of chains/burn in)'


    if (cool /= 1) call CoolChain(cool)
    !Adjust weights if requested
    if (adjust_priors) then
        call AdjustPriors
    end if

    call GetUsedCols !See which parameters are fixed

    mean_mult = sum(coldata(1,0:nrows-1))/nrows

    max_mult = (mean_mult*nrows)/min(nrows/2,500)
    outliers = count(coldata(1,0:nrows-1) > max_mult)
    if (outliers /=0) write (*,*) 'outlier fraction ', real(outliers)/nrows

    maxmult = maxval(coldata(1,0:nrows-1))
    numsamp = sum(coldata(1,0:nrows-1))

    if (.not. no_tests) call DoConvergeTests
    if (adjust_priors) call DeleteZeros

    write (*,*) 'mean input multiplicity = ',mean_mult

    !Output thinned data if requested
    !Must do this with unsorted output
    if (thin_factor /= 0) then
        call ThinData(thin_factor)
        call WriteThinData(trim(rootdirname)//'_thin.txt',thin_cool)
    end if

    !Produce file of weight-1 samples if requested

    if (num_3D_plots/=0 .and. .not. make_single_samples ) then
        make_single_samples = .true.
        single_thin = max(1,nint(numsamp/maxmult)/2000)
    end if

    !Only use variables whose label's are not empty (and in list of plotparams if plotparams_num /= 0)
    num_vars = 0

    if (plotparams_num/=0) then
        do j=1, plotparams_num
            ix = plotparams(j)+2
            if (ix <=ncols .and. labels(ix) /= '' .and. isused(ix)) then
                num_vars = num_vars + 1
                colix(num_vars) = ix
            end if
        end do
    else
        do ix = 3,ncols
            if (labels(ix) /= '' .and. isused(ix)) then
                if (plotparams_num == 0 .or. any(plotparams(1:plotparams_num)==ix-2)) then
                    num_vars = num_vars + 1
                    colix(num_vars) = ix
                end if
            end if
        end do
    end if
    do j = 1, num_vars
        mean(j) = sum(coldata(1,0:nrows-1)*coldata( colix(j),0:nrows-1))/numsamp
        sddev(j)  = sqrt(sum(coldata(1,0:nrows-1)*(coldata(colix(j),0:nrows-1) &
        -mean(j))**2)/numsamp)
    end do

    if (make_single_samples) call MakeSingleSamples(single_thin)

    !Sort data in order of likelihood of points

    call SortColData(2)

    numsamp = sum(coldata(1,0:nrows-1))

    !Get ND confidence region (index into sorted coldata)
    counts = 0
    ND_cont1=-1; ND_cont2=-1
    do j=0, nrows -1
        counts = counts + coldata(1,j)
        if (counts > numsamp*contours(1) .and. ND_cont1==-1) then
            ND_cont1 = j
            if (ND_cont2 /= -1) exit
        end if
        if (counts > numsamp*contours(2) .and. ND_cont2==-1) then
            ND_cont2 = j
        end if
    end do

    triangle_plot = triangle_plot .and. (num_vars > 1)
    if (triangle_plot) then
        if(triangle_num==-1) then
            triangle_num=num_vars
            triangle_params(1:triangle_num) = [1:num_vars]
        else
            ix=triangle_num
            do j=ix,1,-1
                ix2=indexOf(triangle_params(j)+2,colix,num_vars)
                if (ix2==0) then
                    triangle_num=triangle_num-1
                    triangle_params(j:triangle_num) = triangle_params(j+1:triangle_num+1)
                else
                    triangle_params(j)= ix2
                end if
            end do
            triangle_plot = triangle_num > 1
        end if
    end if

    write (*,*) 'using ',nrows,' rows, processing ',num_vars,' parameters'
    if (indep_thin/=0) then
        write (*,*) 'Approx indep samples: ', nint(numsamp/indep_thin)
    else
        write (*,*) 'effective number of samples (assuming indep): ', nint(numsamp/maxmult)
    end if
    !Get covariance matrix and correlation matrix

    call GetCovMatrix
    if (PCA_num>0 .and. .not. plots_only) call PCA(PCA_params,PCA_num,PCA_func, PCA_NormParam)


    !Find best fit, and mean likelihood
    bestfit_ix = 0 !Since we have sorted the lines
    maxlike = coldata(2,bestfit_ix)
    write (*,*) 'Best fit -Ln(like) = ', maxlike

    if (coldata(2,nrows-1) - maxlike < 30) then
        meanlike = log(sum(exp((coldata(2,0:nrows-1) -maxlike))*coldata(1,0:nrows-1)) &
        / numsamp) + maxlike
        write (*,*) 'Ln(mean 1/like) = ', meanlike
    end if

    meanlike = sum(coldata(2,0:nrows-1)*coldata(1,0:nrows-1)) / numsamp
    write (*,*) 'mean(-Ln(like)) = ', meanlike

    meanlike = -log(sum(exp(-(coldata(2,0:nrows-1) -maxlike))*coldata(1,0:nrows-1)) &
    / numsamp) + maxlike
    write (*,*) '-Ln(mean like)  = ', meanlike


    !Output files for 1D plots

    plot_col =  nint(sqrt(num_vars/1.4))
    plot_row = (num_vars +plot_col-1)/plot_col

    !So we don't forget to run sm, delete current .ps file
    call DeleteFile(trim(rootname)//'.ps')


    open(unit=51,file=trim(rootdirname) // '.m',form='formatted',status='replace')
    !MatLab file for 1D plots
    call WriteMatLabInit(51,num_vars>3, matlab_subplot_size_inch)

    cont_lines = 0

    !Do 1D bins
    do j = 1,num_vars
        ix = colix(j)
        bincounts = 0
        binlikes = 0
        binmaxlikes = 0
        binsraw = 0

        do ix1 = 1, num_contours
            limfrac = (1-contours(ix1))
            if (.not. has_limits(ix) .or. force_twotail) then
                limfrac = limfrac/2 !two tail
            end if
            cont_lines(j,2,ix1) = ConfidVal(ix,limfrac,.true.)
            cont_lines(j,1,ix1) = ConfidVal(ix,limfrac,.false.)
        end do !contour lines


        if (has_limits_bot(ix)) then
            amin = limmin(ix)
        else
            amin = ConfidVal(ix,0.001_mcp,.false.)
        end if

        if (has_limits_top(ix)) then
            amax = limmax(ix)
        else
            amax = ConfidVal(ix,0.001_mcp,.true.)
        end if


        width(j) = (amax-amin)/(nbins+1)
        if (width(j)==0) cycle

        !        if (amin <= 0) then
        !          center(j) = amax
        !        else
        !          center(j) = amin
        !        end if
        if (has_limits_top(ix)) then
            center(j) = amax !- width(j)/2
        else
            center(j) = amin !+ width(j)/2
        end if

        ix_min(j) = nint((amin - center(j))/width(j))
        ix_max(j) = nint((amax - center(j))/width(j))

        if (smoothing .and. .not. has_limits_bot(ix)) ix_min(j) = ix_min(j)-1
        if (smoothing .and. .not. has_limits_top(ix)) ix_max(j) = ix_max(j)+1

        do i = 0, nrows-1
            ix2=nint((coldata(ix,i)-center(j))/width(j))
            binsraw(ix2) = binsraw(ix2) + coldata(1,i)

            if (smoothing .and. ix_min(j) /= ix_max(j)) then
                do wx = max(ix_min(j),ix2-2),min(ix_max(j),ix2+2)
                    dist = coldata(colix(j),i) - (center(j) + wx*width(j))
                    distweight = exp(- dist**2/width(j)**2/2)
                    binweight = coldata(1,i)*distweight
                    bincounts(wx) = bincounts(wx)  + binweight
                    binlikes(wx) = binlikes(wx) + binweight*exp(meanlike-coldata(2,i))
                    binmaxlikes(wx) = max(binmaxlikes(wx), &
                    real(exp(maxlike-coldata(2,i))*distweight))
                end do
            else
                bincounts(ix2) = bincounts(ix2) + coldata(1,i)
                binlikes(ix2) = binlikes(ix2) + coldata(1,i)*exp(meanlike-coldata(2,i))
                binmaxlikes(ix2) = max(binmaxlikes(ix2), real(exp(maxlike-coldata(2,i))))
            end if
        end do


        do i=ix_min(j),ix_max(j)
            if (bincounts(i) >0) binlikes(i) = binlikes(i)/bincounts(i)
        end do

        if (ix_min(j) /= ix_max(j)) then

        !account for underweighting near edges
        if (has_limits_bot(ix)) then
            bincounts(ix_min(j))   = bincounts(ix_min(j))*2
            if (smoothing) bincounts(ix_min(j)+1) = bincounts(ix_min(j)+1)/0.84
        else
            if (binsraw(ix_min(j))==0  .and. &
            binsraw(ix_min(j)+1) >  maxval(binsraw(ix_min(j):ix_max(j)))/15) then
                call EdgeWarning(ix-2)
            end if
        end if
        if (has_limits_top(ix)) then
            bincounts(ix_max(j))   = bincounts(ix_max(j))*2
            if (smoothing) bincounts(ix_max(j)-1) = bincounts(ix_max(j)-1)/0.84
        else
            if (binsraw(ix_max(j))==0  .and. &
            binsraw(ix_max(j)-1) >  maxval(binsraw(ix_min(j):ix_max(j)))/15) then
                call EdgeWarning(ix-2)
            end if

        end if

        end if

        !!!!!!!!!!!!!!!!!!!!!!!!!!!! JH: start of MCI stuff !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        if (do_minimal_1d_intervals) then ! Calculate minimal credible intervals (see arXiv:0705.0440)

        do ix1 = 1, num_contours ! get boundaries of minimal intervals
            minimal_intervals(j,:,ix1) = MinInterval(contours(ix1),bincounts,width(j),center(j), &
            has_limits_bot(ix),has_limits_top(ix),ix_min(j),ix_max(j))

            if (int(minimal_intervals(j,max_intersections+1,ix1)).ne.2) then ! if minimal region is not connected ...
                Write(*,*) 'Warning: the minimal '& ! ... spam screen with warning ...
                //trim(intToStr(nint(100*contours(ix1))))// '% credible region in parameter ' &
                //trim(intToStr(colix(j)-2))// &
                ' does not seem to be connected. Perhaps the posterior is multimodal?'// &
                'You might also want to try choosing a larger bin size and/or turn on smoothing to reduce noise.'
                Write(*,*) 'There are '//trim(intToStr(int(minimal_intervals(j,max_intersections+1,ix1))/2))//&
                'disconnected regions:' ! ... output intervals to screen and ...
                do i=1,int(minimal_intervals(j,max_intersections+1,ix1))/2
                    Print*,minimal_intervals(j,2*i-1,ix1),' -> ',minimal_intervals(j,2*i,ix1)
                    minimal_intervals(j,2*i-1,ix1)=0. ! ... set output in .minmarge file to zero to avoid confusion
                    minimal_intervals(j,2*i,ix1)=0.
                end do
            end if
        end do
        end if
        !!!!!!!!!!!!!!!!!!!!!!!!!!!! JH: end of MCI stuff !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


        if (.not. no_plots) then

        filename = trim(plot_data_dir)//trim(rootname)//'.m'
        call CreateTxtFile(trim(filename),49)
        write(49,'(a)') 'classdef '//trim(trim(rootname))//' < handle'
        write(49,'(a)') 'properties'
        write(49,'(a)') 'last=[];'
        write(49,'(a)') 'distroot='''//trim(rootdirname)//''';'
        write(49,'(a)') 'plotroot='''//trim(plot_data_dir)//trim(rootname)//''';'
        write(49,'(a)') 'root='''//trim(rootname)//''';'
        call ParamNames_WriteMatlab(NameMapping,  49,'')
        write(49,'(a)') 'end'
        write(49,'(a)') 'end'
        close(49)

        fname = trim(dat_file_name(rootname,j))
        filename = trim(plot_data_dir)//trim(fname)
        open(unit=49,file=trim(filename)//'.dat',form='formatted',status='replace')
        maxbin = maxval(bincounts(ix_min(j):ix_max(j)))
        if (maxbin==0) then
            fname =  IntToStr(colix(j)-2)
            write (*,*) 'no samples in bin, param:'//trim(fname)
            stop
        end if
        do i = ix_min(j), ix_max(j)
            write (49,'(3E16.7)') center(j) + i*width(j), bincounts(i)/maxbin, binmaxlikes(i)
        end do
        if (ix_min(j) == ix_max(j)) write (49,'(1E16.7,'' 0'')') center(j) + ix_min*width(j)
        close(49)

        !Detect ends which don't go to zero
        if (.not. force_twotail) then
            if (bincounts(ix_max(j)) > maxbin*.15) cont_lines(j,2,:) = amax
            if (bincounts(ix_min(j)) > maxbin*.15) cont_lines(j,1,:) = amin
        end if

        if (plot_meanlikes) then

        open(unit=49,file=trim(filename)//'.likes',form='formatted',status='replace')
        maxbin = maxval(binlikes(ix_min(j):ix_max(j)))
        do i = ix_min(j), ix_max(j)
            write (49,'(2E16.7)') center(j) + i*width(j), binlikes(i)/maxbin
        end do
        close(49)
        end if

        !        plot_x = mod(j+plot_col-1,plot_col)+1
        !        plot_y = plot_row - (j+plot_col-1)/plot_col + 1

        call WriteFormatInts(51,'subplot(%u,%u,%u);',plot_row,plot_col,j)
        call Write1DplotMatLab(51,j);
        if (prob_label)  write (51,*) 'ylabel(''Probability'')'
        write(51,*)  'xlabel('''//   trim(matlabLabel(ix))//''',''FontSize'',lab_fontsize);'
        write (51,*) 'set(gca,''ytick'',[]);hold off;'

        end if !no plots
    end do

    if (.not. no_plots) then
        if (line_labels) call WriteMatlabLineLabels(51)
        call WriteMatLabPrint(51, '', plot_col, plot_row)
        close(51)

        if (triangle_plot) then
            open(unit=52,file=trim(rootdirname) // '_tri.m',form='formatted',status='replace')
            call WriteMatLabInit(52,num_vars>4, matlab_subplot_size_inch)
            !    if (num_vars>6) write(52,*) 'axes_fontsize=axes_fontsize*2/3;lab_fontsize=lab_fontsize-1;'
            do i=1, triangle_num
                j=triangle_params(i)
                call WriteFormatInts(52,'subplot(%u,%u,%u);',triangle_num,triangle_num,(i-1)*triangle_num+i)
                call Write1DplotMatLab(52,j);
                if (triangle_num > 2 .and. matlab_subplot_size_inch<3.5) call CheckMatlabAxes(52)
                if (prob_label)  write (52,*) 'ylabel(''Probability'')'
                if (j==num_vars) then
                    write(52,*)  'xlabel('''//   trim(matlabLabel(colix(j)))//''',''FontSize'',lab_fontsize);'
                else if (no_triangle_axis_labels) then
                    write(52,*) 'set(gca,''xticklabel'',[]);'
                end if
                write (52,*) 'set(gca,''ytick'',[]);hold off;'
            end do

        end if

    end if


    !do 2D bins and produce matlab file

    if (plot_2D_param == 0 .and. num_cust2D_plots==0 .and. .not. no_plots) then
        !In this case output the most correlated variable combinations

        write (*,*) 'doing 2D plots for most correlated variables'
        try_t = 1e5

        x=0;y=0;

        num_cust2D_plots = 12
        do j = 1, num_cust2D_plots
            try_b = -1e5
            do ix1 =1 ,num_vars
                do ix2 = ix1+1,num_vars
                    if (abs(corrmatrix(colix(ix1)-2,colix(ix2)-2)) < try_t .and. &
                    abs(corrmatrix(colix(ix1)-2,colix(ix2)-2)) > try_b) then
                        try_b = abs(corrmatrix(colix(ix1)-2,colix(ix2)-2))
                        x = ix1; y = ix2;
                    end if
                end do
            end do
            if (try_b == -1e5) then
                num_cust2D_plots = j-1
                exit
            end if
            try_t = try_b

            cust2Dplots(j) = colix(x) + colix(y)*1000
        end do

    end if


    if (num_cust2D_plots == 0) then
        num_2D_plots = 0

        do j= 1, num_vars
            if (ix_min(j) /= ix_max(j)) then
                do j2 = j+1, num_vars
                    if (ix_min(j2) /= ix_max(j2)) then
                        if (plot_2D_param==0 .or. plot_2D_param == colix(j) .or. plot_2D_param == colix(j2)) &
                        num_2D_plots = num_2D_plots + 1
                    end if
                end do
            end if
        end do
    else
        num_2D_plots = num_cust2D_plots
    end if

    done2D= .false.
    if (num_2D_plots > 0 .and. .not. no_plots) then

    write (*,*) 'Producing ',num_2D_plots,' 2D plots'
    filename = trim(rootdirname)//'_2D.m'
    open(unit=50,file=filename,form='formatted',status='replace')
    call WriteMatLabInit(50,num_2D_plots >=7,matlab_subplot_size_inch2)

    plot_col = nint(sqrt(num_2D_plots/1.4))
    plot_row = (num_2D_plots +plot_col-1)/plot_col
    plot_num = 0


    do j= 1, num_vars
        if (ix_min(j) /= ix_max(j)) then

        if (plot_2D_param/=0 .or. num_cust2D_plots /= 0) then
            if (colix(j) == plot_2D_param) cycle
            j2min = 1
        else
            j2min = j+1
        end if

        do j2 = j2min, num_vars
            if (ix_min(j2) /= ix_max(j2)) then

            if (plot_2D_param/=0 .and. colix(j2) /= plot_2D_param) cycle
            if (num_cust2D_plots /= 0 .and.  &
            count(cust2Dplots(1:num_cust2D_plots) == colix(j)*1000 + colix(j2))==0) cycle

            plot_num = plot_num + 1
            done2D(j,j2) = .true.
            if (.not. plots_only) call Get2DPlotData(j,j2)
            call WriteFormatInts(50,'subplot(%u,%u,%u);',plot_row,plot_col,plot_num)
            call Write2DPlotMATLAB(50,j,j2,.true.,.true.)
            if (plot_row*plot_col > 4 .and. matlab_subplot_size_inch<3.5) call CheckMatlabAxes(50)

            end if
        end do
        end if
    end do

    if (line_labels) call WriteMatlabLineLabels(50)
    if (matlab_col/='') write (50,*) trim(matlab_col)
    call WriteMatLabPrint(50, '_2D', plot_col, plot_row)
    close(50)

    end if

    if (triangle_plot .and. .not. no_plots) then
        !Add the off-diagonal 2D plots
        do i = 1, triangle_num
            do i2 = i+1, triangle_num
                j= triangle_params(i)
                j2=triangle_params(i2)
                if (.not. Done2D(j2,j) .and. .not. plots_only) call Get2DPlotData(j2,j)
                call WriteFormatInts(52,'subplot(%u,%u,%u);',triangle_num,triangle_num,(i2-1)*triangle_num + i)
                call Write2DPlotMATLAB(52,j2,j,i2==triangle_num, i==1,no_triangle_axis_Labels)
                if (triangle_num > 2 .and. matlab_subplot_size_inch<3.5) call CheckMatlabAxes(52)
            end do
        end do
        !  write (52,*)  'set(gcf, ''PaperUnits'',''inches'');'
        !  write (52,*) 'set(gcf, ''PaperPosition'',[ 0 0 8 8]);';
        if (no_triangle_axis_labels) then
            write(52,*) 'h = get(gcf,''Children'');'
            write(52,*) 'for i=1:length(h)'
            write(52,*) 'p=get(h(i),''position'');'
            write(52,*) 'sc=1.2;w=max(p(3)*sc,p(4)*sc);'
            write(52,*) 'p(1)=p(1)-(w-p(3))/2; p(2)=p(2)-(w-p(4))/2;p(3)=w;p(4)=w;'
            write(52,*) 'set(h(i),''position'',p);'
            write(52,*) 'end;'
        end if
        call WriteMatLabPrint(52, '_tri', triangle_num+1, triangle_num+1)
        close(52)

    end if


    !Do 3D plots (i.e. 2D scatter plots with coloured points)

    if (num_3D_plots /=0 .and. .not. no_plots) then
        write (*,*) 'producing ',num_3D_plots, '2D colored scatter plots'
        filename = trim(rootdirname)//'_3D.m'
        open(unit=50,file=filename,form='formatted',status='replace')
        call WriteMatLabInit(50,num_3D_plots>1,matlab_subplot_size_inch3)
        write (50,*) 'clf;colormap(''jet'');'

        if (mod(num_3D_plots,2)==0 .and. num_3D_plots < 11) then
            plot_col = num_3D_plots/2
        else
            plot_col =  nint(sqrt(1.*num_3D_plots))
        end if
        plot_row = (num_3D_plots +plot_col-1)/plot_col

        write(50,'(a)') 'pts=load(fullfile(plotdir,''' // trim(rootname)//'_single.txt''));'

        do j=1, num_3D_plots
            call ParamNames_ReadIndices(NameMapping,plot_3D(j), tmp_params, 3)
            !x, y, color
            ix1 = indexOf(tmp_params(1)+2,colix,num_vars)+2
            ix2 = indexOf(tmp_params(2)+2,colix,num_vars)+2
            ix3 = indexOf(tmp_params(3)+2,colix,num_vars)+2
            if (any([ix1,ix2,ix3]<=0)) then
                write (*,*) 'Warning: 3D plot parameters not in used parameters'
                continue
            end if
!            if (ix3<1) ix3 = MostCorrelated2D(ix1,ix2,ix3)

            call WriteFormatInts(50,'subplot(%u,%u,%u);', plot_row,plot_col,j)
            write (50,*) '%Do params ',tmp_params(1:3)
            call WriteFormatInts(50,'scatter(pts(:,%u),pts(:,%u),3,pts(:,%u));', ix1,ix2,ix3)
            fmt = ''',''FontSize'',lab_fontsize);'
            write (50,*) 'xlabel('''//trim(matlabLabel(tmp_params(1)+2))//trim(fmt)
            write (50,*) 'ylabel('''//trim(matlabLabel(tmp_params(2)+2))//trim(fmt)
            write (50,*) 'set(gca,''FontSize'',axes_fontsize); ax = gca;'
            write (50,*) 'hbar = colorbar(''horiz'');axes(hbar);'

            write (50,*) 'xlabel('''//trim(matlabLabel(tmp_params(3)+2))//trim(fmt)
            write (50,*) 'set(gca,''FontSize'',axes_fontsize);'
            if (num_3D_plots > 2 .and. matlab_version < 7) then
                write (50,*) ' p = get(ax,''Position'');'
                write (50,*) 'set(ax,''Position'',[p(1) (p(2)+p(4)/8) p(3) p(4)]);'
            elseif (matlab_version==7) then
                !workaround for colorbar/label overlap bug
                write (50,*) 'fix_colorbar(hbar,ax); axes(ax);'
            end if
        end do

        call WriteMatLabPrint(50, '_3D', plot_col, plot_row)
        close(50)
    end if

    !write out stats
    !Marginalized
    if (.not. plots_only) &
    call IO_OutputMargeStats(NameMapping, rootdirname, num_vars,num_contours,contours, contours_str, &
    cont_lines, colix, mean, sddev, has_limits_bot, has_limits_top, labels, force_twotail)

    call ParamNames_WriteFile(NameMapping, trim(plot_data_dir)//trim(rootname)//'.paramnames', colix(1:num_vars)-2)
    open(unit=51,file=trim(plot_data_dir)//trim(rootname)//'.paramnames',form='formatted',status='replace')
    do j=1, num_vars
        write(51,'(a)') trim(ParamNames_AsString(NameMapping,colix(j)-2))
    end do
    close(51)

    !Limits from global likelihood
    if (.not. plots_only) then

    open(unit=50,file=trim(rootdirname)//'.likestats',form='formatted',status='replace')
    write (50,*) 'Best fit sample -log(Like) = ',coldata(2,bestfit_ix)
    write (50,*) ''
    write(50,'(a)') 'param  bestfit        lower1         upper1         lower2         upper2'

    do j=1, num_vars

    write(50,'(1I5,5E15.7,"   '//trim(labels(colix(j)))//'")') colix(j)-2, coldata(colix(j),bestfit_ix),&
    minval(coldata(colix(j),0:ND_cont1)), &
    maxval(coldata(colix(j),0:ND_cont1)), &
    minval(coldata(colix(j),0:ND_cont2)), &
    maxval(coldata(colix(j),0:ND_cont2))

    end do
    close(50)

    end if


    !!!!!!!!!!!!!!!!!!!!!!!!!!!! JH: beginning of MCI stuff !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    if (do_minimal_1d_intervals .and. .not. plots_only) then ! write limits to .minmarge file

    open(unit=50,file=trim(rootdirname)//'.minmarge',form='formatted',status='replace')
    write(50,'(a)',advance='NO') 'param  '
    do j=1, num_contours
        write(50,'(a)',advance='NO') trim(concat('lower',j))//'         '//trim(concat('upper',j))//'         '
    end do
    write(50,'(a)') ''

    do j=1, num_vars
        write(50,'(1I5)', advance='NO') colix(j)-2
        do i=1, num_contours
            write(50,'(2E15.7)',advance='NO') minimal_intervals(j,1:2,i)
        end do
        write(50,'(a)') '   '//trim(labels(colix(j)))
    end do
    write (50,*) ''
    write (50,'(a)') 'Limits are: ' // trim(contours_str)
    close(50)

    end if
    !!!!!!!!!!!!!!!!!!!!!!!!!!!! JH: end of MCI stuff !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    !Comment this out if your compiler doesn't support "system"
    if (finish_run_command /='') then
        call StringReplace('%ROOTNAME%',rootname,finish_run_command)
        call StringReplace('%PLOTDIR%',trim(plot_data_dir),finish_run_command)
        call StringReplace('%PLOTROOT%',trim(plot_data_dir)//rootname,finish_run_command)
        call system(finish_run_command)
    end if
    end program GetDist
