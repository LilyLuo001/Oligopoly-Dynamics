
function [] = eql_ma()


% #include pmg.h;
% "**** Computing Dynamic Equilibrium ****";
% #include init.h;
% constants not modifiable by user

global c kmax x_entryl x_entryh phi entry_k beta delta a
global binom dtable encfirm etable1 etable2 isentry mask multfac1 multfac2
global newvalue newx nfirms oldvalue oldx profit two_n wmax

kmax = c.KMAX;
x_entryl = c.ENTRY_LOW;
x_entryh = c.ENTRY_HIGH;
phi = c.SCRAP_VAL;
entry_k = c.ENTRY_AT;
rlnfirms = c.MAX_FIRMS;
stfirm = c.START_FIRMS;
beta = c.BETA;
delta = c.DELTA;
a = c.INV_MULT;

tol = 0.1;  % Tolerance for convergence
newvalue = []; newx = []; oldvalue = []; oldx = []; isentry = [];

% Set up binomial coefficients for decoding/encoding of n-tuples

binom = eye(rlnfirms+kmax+1);
binom = [zeros(rlnfirms+kmax+1,1),binom];
i=2;
while i <= rlnfirms+kmax+1;
  binom(i,2:i) = binom(i-1,2:i) + binom(i-1,1:i-1);
  i=i+1;
  end
encfirm = 3;  % Max. number of firms to encode in table

oneton = 1;
nfirms = stfirm; % max. # of firms at each computation stage

if nfirms > 1;
  nfirms = nfirms - 1;
  wmax = binom(nfirms+1+kmax,kmax+2);

  % Read in data
  % This data is: v (value), x (investment), p (probability of state rising),
  %   isentry


  global newvalue newx prising isentry
  load(['a.' c.PREFIX '_markov' int2str(nfirms) '.mat']);

  oneton = zeros(nfirms,1);
  i=1;
  while i <= nfirms;
    oneton(i) = i;
    i=i+1;
    end

  if nfirms >= encfirm;
    multfac1 = (kmax+1)^(oneton(1:encfirm)-1);
    nfirms = encfirm;

    % Encode all numbers from 1 to kmax^nfirms

    etable1 = zeros((kmax+1)^nfirms,1);
    i=0;
    while i < rows(etable1);
      msk = [];
      j=kmax+1; k=i;
      while j <= rows(etable1);
        msk = [((mod(k, j))*(kmax+1)/j);msk];
        k = k - (mod(k, j));
        j = j*(kmax+1);
        end
      etable1(i+1) = encode(flipud(sortrows(msk(1:nfirms),1)));
      i=i+1;
      end
    nfirms = stfirm-1;
    if nfirms > encfirm;
      multfac1 = [zeros(nfirms-encfirm,1);multfac1];
      end
    end
  nfirms = stfirm;
  end

while nfirms <= rlnfirms;

% Number of different combinations of competitors positions faced by a firm

  wmax = binom(nfirms+1+kmax,kmax+2);

  disp(sprintf('\nFirms: %d   States: %d\nInitialization ...', nfirms, wmax));

  load(['a.' c.PREFIX '_pr' int2str(nfirms) '.mat'])

  two_n = 2^(nfirms-1);
  dtable = [];

  if nfirms > 1;
    oneton = [oneton;nfirms];
    % Build a mask of all binary numbers from 0 to two_n - 1
    mask = zeros(nfirms-1,two_n);
    i=0;
    while i < two_n;
      msk = [];
      j=2; k=i;
      while j <= two_n;
        if mod(k, j) == 0;
          msk = [0;msk];
        else; k = k - j/2; msk = [1;msk];
          end
        j = j*2;
        end
      mask(:,i+1) = msk(1:nfirms-1);
      i=i+1;
      end
    %print "Mask is " mask;
    end

  % Make a table for quick decoding

  dtable = zeros(nfirms,wmax);
  i=1;
  while i <= wmax;
    dtable(:,i) = decode(i);
    i=i+1;
    end

  % Make a table for quick encoding
  % Fill in multfac1, multfac2, for quick encoding

  if nfirms <= encfirm;
    multfac1 = (kmax+1).^(oneton-1);
    % Encode all numbers from 1 to kmax^nfirms
    etable1 = zeros((kmax+1)^nfirms,1);
    i=0;
    while i < rows(etable1);
      msk = [];
      j=kmax+1; k=i;
      while j <= rows(etable1);
        if isempty(msk) msk = [mod(k, j)*(kmax+1)/j];
        else msk = [mod(k, j)*(kmax+1)/j;msk];
          end
        k = k - (mod(k, j));
        j = j*(kmax+1);
        end
      etable1(i+1) = encode(flipud(sortrows(msk(1:nfirms),1)));
      i=i+1;
      end
  else;
    multfac1 = [0;multfac1];
    multfac2 = [(kmax+1)^(oneton(1:nfirms-encfirm)-1);zeros(encfirm,1)];
    % "Multfac1 is " multfac1;
    % "Multfac2 is " multfac2;
    etable2 = zeros((kmax+1)^(nfirms-encfirm),1);
    i=0;
    while i < rows(etable2);
      msk = [];
      j=kmax+1; k=i;
      while j <= rows(etable2);
        msk = [((mod(k, j))*(kmax+1)/j);msk];
        k = k - (mod(k, j));
        j = j*(kmax+1);
        end
      etable2(i+1) = encode(flipud(sortrows(([msk(1:nfirms-encfirm); ...
        zeros(encfirm,1)]),1)))-1;
      i=i+1;
      end
    end

  % Update values, or define starting values.

  update;
  disp(sprintf('Contraction ...'));
  ix = 1;

  norm = tol + 1;
  avgnorm = norm;
  while (norm > tol) & (avgnorm > 0.0001*tol);
    contract;
    norm = max(max(abs(oldvalue - newvalue)));
    avgnorm = mean(mean(abs(oldvalue-newvalue)));

    disp(sprintf('  %2d    Sup norm: %8.4f      Mean norm: %8.4f', ...
      ix, norm, avgnorm));
    ix = ix+1;

    aaaaa = abs(oldvalue-newvalue);
    normind1 = maxind(max(aaaaa'));
    normind2 = maxind(max(aaaaa));
    normcode = (qdecode(normind1))';

    % "Max. elt is: " normind2 "," normcode "; Old value: "
    % oldvalue(normind1,normind2) "; New value: "
    % newvalue(normind1,normind2) "";
  
    oldx = newx; oldvalue = newvalue;
    end

  % d2 = date;
  % Now find if there is any investment at the highest level.

  w=kmax;
  if nfirms > 1;
    w = [w;zeros(nfirms-1,1)];
    end
  if max(newx(qencode(w):wmax,1)) > 0;
    disp('Warning: Positive investment recorded at highest efficiency level.')
    disp('Please consider increasing the maximum efficiency level (kmax).')
    end

% Store data in file for inspection
% Store data in file for comparative statics program to read

  prising = a.*newx./(1+a.*newx);
  save(['a.' c.PREFIX '_markov' int2str(nfirms) '.mat'], ...
    'newvalue', 'newx', 'prising', 'isentry')

% disp(sprintf('\n'))
% disp('Value Function (wmax x nfirms)')
% disp([dtable' newvalue])
% disp('Investment (wmax x nfirms)')
% disp([dtable' newx])
% disp('Probability of p rising (wmax x nfirms)'),
% disp([dtable' prising])
% disp('Probability of entry (wmax x nfirms)')
% disp([dtable' isentry])

  nfirms = nfirms+1;
  end

c.EQL_DONE = 1;



function [] = contract()
  % This procedure does one iterative step on investment and the value fn
  % Implicit parameters are oldx, oldvalue (passed in) and newx, newvalue,
  %  which are returned
  % local w;
  % First: check for which values of w_s would a firm want to enter

  global newvalue newx oldvalue oldx wmax
  chkentry;

  % Above is vector of whether firms want to enter, for any w1,...,wn-1

  w = 1;
  while w <= wmax;
    [newx(w,:), newvalue(w,:)] = optimize(w);
    w=w+1;
    end

  % Implicit returned parameters: newx, newvalue



function [] = update()
% This procedure takes the solved newx, newvalue matrix for the nfirms - 1
% problem, and puts them into the nfirms matrices oldx, oldvalue, for use
% as starting values
% local w,i,n,tuple;

  global isentry nfirms wmax newvalue newx oldvalue oldx
  oldx = zeros(wmax,nfirms);
  oldvalue = zeros(wmax,nfirms);
  if nfirms == 1;
    i=1;
    while i <= wmax;
      oldvalue(i,:) = 1 + 0.1*i;
      i=i+1;
      end
  else;
    w=1;
    while w <= wmax;
      tuple = qdecode(w);
      nfirms = nfirms - 1;
      n = encode(tuple(1:nfirms));
      oldx(w,1:nfirms) = newx(n,1:nfirms);
      oldvalue(w,1:nfirms) = newvalue(n,1:nfirms);
      nfirms = nfirms + 1;
      tuple(nfirms-1) = tuple(nfirms);
      tuple(nfirms) = 0;
      oldvalue(w,nfirms) = oldvalue(encode(tuple),nfirms-1);
      oldx(w,nfirms) = oldx(encode(tuple),nfirms-1);
      w=w+1;
      end
    end
  isentry = zeros(wmax,1);
  newx = zeros(wmax,nfirms);
  newvalue = zeros(wmax,nfirms);

  % Implicit returned value: oldx, oldvalue



function [out1,out2] = optimize(w)
% This procedure calculates optimal investment, and value fn., for a
% given industry structure w. Thus, a vector nfirms long of each is returned.
% Implicit parameters are oldx, oldvalue, isentry
% local locw,locwx,locwe,  % Decoded copies of other's omegas w and w/o entry
%   oval,ox, % Old local values
%   entered, % Indicates the probability of an entrant
%   v1,v2,  % v1: value of investing; v2: value of not investing
%   i,j,p,r,tempv1,tempv2,temp, nval,nx; % Returned values of investment, value fn.

  global a beta entry_k isentry nfirms oldvalue oldx phi profit
  locw = qdecode(w);
  locwx = locw;
  oval = oldvalue(w,:)';
  ox = oldx(w,:)';
  nval = zeros(nfirms,1);
  nx = zeros(nfirms,1);

  % Find out which firms want to exit

  i = (min(oval) == phi)*(minind(oval)-1) + (min(oval) > phi)*nfirms;

  % Replace efficiency levels of exitors with zero

  if i < nfirms;
    locwx(i+1:nfirms) = zeros(nfirms-i,1);
    end

  % Figure out the probability of entry

  entered = isentry(qencode(flipud(sortrows(flipud(locwx),1))));
  locwe = locwx;
  locwe(nfirms) = entry_k;

  % Now calculate the optimal policies for this industry structure, given that
  % entry and exit are as specified.

  j=1;
  while j <= nfirms;
    if locw(j) == 0;
      nval(j:nfirms) = phi*ones(nfirms-j+1,1);
      break;
      end
    v1=0; v2=0;
    if entered < 1;

      % First: Calculate v, without entry

      [v1, v2] = calcval(j,locwx,ox,locw(j));
      end

    if entered > 0;

      % A firm wants to enter with positive probability

      [tempv1, tempv2] = calcval(j,locwe,ox,locw(j));
      v1 = entered*tempv1 + (1-entered)*v1;
      v2 = entered*tempv2 + (1-entered)*v2;
      end

    % Calculate values for firm, given that it is not leaving

    if v1 <= v2; % Avoid division by zeros
      r = 1.0;
    else; r = 1.0/(beta*a*(v1-v2));
      end

    % r now contains the value r = (1 - p)^2. => p = 1 - sqrt(r)),
    % where p is the optimal prob. of having k rise, cond. on world

    r = min([max([r;0.0000000000001]);1]);
    p = 1.0 - sqrt(r);
    nx(j) = p/(a - a * p);

    % Now calculate the value from staying in
    % Ask: given this optimal investment level, will there be exit?

    nval(j) = profit(w,j) - nx(j) + beta*(v1*p + v2*(1-p));
    if nval(j) <= phi;
      nval(j) = phi;
      nx(j) = 0;
      end
    if (j < nfirms) & (nval(j) == phi);
      nval(j+1:nfirms) = ones(nfirms-j,1) * phi;
      break;
      end
    ox(j) = nx(j);
    locwx(j) = (nval(j) > phi)*locw(j);
    locwe(j) = locwx(j);
    j=j+1;
    end

  out1 = nx';
  out2 = nval';


function [] = chkentry()
% This procedure calculates for which value of other people's omegas, would
% a firm want to enter, given that there is room in the market for
% a firm to enter
% Implicit parameters are oldx, oldvalue (passed in) and isentry (returned)
% local w,locw,v1,vgarbage,
%   val; % Value from entering

  global beta entry_k isentry nfirms wmax oldvalue oldx x_entryl x_entryh
  w = 1;
  while w <= wmax;
    locw = qdecode(w);
    if locw(nfirms) == 0;
      [vgarbage,v1] = calcval(nfirms,locw,oldx(w,:)',entry_k);
      val = beta * v1;

      % print val-x_entry;

      isentry(w) = (val - x_entryl) / (x_entryh - x_entryl);
      end
    w=w+1;
    end
  isentry = min([isentry,ones(wmax,1)]')';
  isentry = max([isentry,zeros(wmax,1)]')';



function [out1,out2] = calcval(place,w,x,k)
% This procedure calculates val = EEEV(.,.,.,.)p(.)p(.)p(.), where E
% represents sums, and this is the calculation of the 4-firm problem
% Vars: place = place of own omega, for calculating value function (v)
%       w = the vector of omegas; already decoded
%       x = the vector of investments (nfirms of them)
% Implicit parameter: oldvalue
% For efficiency reasons, it outputs the following vector:
% [ calcval(k_v+1,w,x), calcval(k_v,w,x) ]
% local i,valA,valB,d,e,probmask,z1,z2,locmask,
%   p_up,  % p_down, p of going up/down for all other firms
%   temp,
%   pl1,justone;

  global a delta kmax mask nfirms oldvalue two_n
  z1 = zeros(nfirms,1);
  z2 = kmax*ones(nfirms,1);

  % Expand mask to allow for the non-inclusion of the ith plant

  if nfirms > 1;
    if place == 1;
      locmask = [zeros(1,two_n);mask];
    elseif place == nfirms;
      locmask = [mask;zeros(1,two_n)];
    else; locmask = [mask(1:place-1,:);zeros(1,two_n);mask(place:nfirms-1,:)];
      end
  else; locmask = zeros(1,1);
    end
  x(place) = 0;
  w(place) = k;
  justone = zeros(nfirms,1);
  justone(place) = 1;
  p_up = (a .* x) ./ (1 + a .* x);
  % p_down = 1 - p_up;
  valA=0; valB=0;
  i=1;

  while i <= two_n;
    % probmask = prod(mask(:,i) .* p_up + (1 - mask(:,i)) .* p_down);
    probmask = prod(2 .* locmask(:,i) .* p_up + 1 - locmask(:,i) - p_up);
    d = w+locmask(:,i);
    temp = flipud(sortrows(flipud([d,justone]),1));
    d = temp(:,1);
    e = d - 1;

    % Check for evaluation of value fn. at -1
    e = max(([e,z1])')';
    % Check for evaluation of value fn. at kmax+1
    d = min(([d,z2])')';
    pl1 = maxind(temp(:,2));% sum(d(1:place)>=k) + sum(d(place:nfirms)>k);

    valB = valB + ((1-delta)*oldvalue(qencode(d),pl1) ...
            + delta*oldvalue(qencode(e),pl1))*probmask;

    d = w+locmask(:,i)+justone;
    temp = flipud(sortrows(flipud([d,justone]),1));
    d = temp(:,1);
    e = d - 1;

    % Check for evaluation of value fn. at -1
    e = max(([e,z1])')';
    % Check for evaluation of value fn. at kmax+1
    d = min(([d,z2])')';
    pl1 = maxind(temp(:,2)); %sum(e(1:place)>=k) + sum(e(place:nfirms)>k);

    valA = valA + ((1-delta)*oldvalue(qencode(d),pl1) ...
            + delta*oldvalue(qencode(e),pl1))*probmask;
    i=i+1;
    end

  out1 = valA;
  out2 = valB;


function [out1] = encode(ntuple)
% This procedure takes a weakly descending n-tuple (n = nfirms), with
% min. elt. 0, max. elt. kmax, and encodes it into an integer
% local code,digit,i;

  global binom nfirms
  code = 1; % Coding is from 1 to wmax
  i = 1;
  while i <= nfirms;
    digit = ntuple(i);
    code = code + binom(digit+nfirms+1-i,digit+1);
    i=i+1;
    end

  out1 = code;


function [out1] = qencode(ntuple)
% This procedure does a quick encode of any n-tuple given in weakly
% descending order. Encoding is done using a table lookup. Each
% column of the table consists of an n-tuple; the ith column is the ith
% n-tuple to be decoded. The table is stored in the variable "etable".

  global encfirm etable1 etable2 multfac1 multfac2 nfirms
  if nfirms <= encfirm;
    out1 = etable1(sum(ntuple.*multfac1)+1);
  else;
    out1 = etable1(sum(ntuple.*multfac1)+1) ...
      + etable2(sum(ntuple.*multfac2)+1);
    end



function [out1] = qdecode(code)
% This procedure does a quick decode of a previously encoded number into
% a weakly descending n-tuple. Decoding is done using a table lookup. Each
% column of the table consists of an n-tuple; the ith column is the ith
% n-tuple to be decoded. The table is stored in the variable "dtable".

  global dtable

  out1 = dtable(:,code);


function [out1] = decode(code)
% This procedure takes a previously encoded number, and decodes it into
% a weakly descending n-tuple (n = nfirms)
% local ntuple,digit,i;

  global binom nfirms
  code = code-1;
  ntuple = zeros(nfirms,1);
  i = 1;
  while i <= nfirms;
    digit = 0;
    while binom(digit+nfirms-i+2,digit+2) <= code;
      digit=digit+1;
      end
    ntuple(i) = digit;
    code = code-binom(digit+nfirms-i+1,digit+1);
    i = i+1;
    end

  out1 = ntuple;
