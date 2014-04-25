BEGIN {
    eval {
        require Bio::Ext::HMM;
    };
    if ( $@ ) {
        die("\nThe C-compiled engine for Hidden Markov Model (HMM) has not been installed.\n Please read the install the bioperl-ext package\n\n");
        exit(1);
}
sub new {
   my ($class, @args) = @_;

   my $self = $class->SUPER::new(@args);

   my ($symbols, $states, $init, $a_mat, $e_mat) = $self->_rearrange([qw(SYMBOLS
								STATES
                                                                INIT
                                                                AMAT
                                                                EMAT
							)], @args);

   $self->throw("Observation Symbols are not defined!") unless defined $symbols; 
   $self->throw("Hidden States are not defined!") unless defined $states; 

   if (defined $symbols) {
      if (scalar($symbols)) {
         # check duplicate symbols
         if ($self->symbols($symbols) < 0) {
            $self->throw("Duplicate symbols!\n");
         }
      }
      else {
         $self->throw("We don't support list of symbols in this version.\n");
      }
   }

   if (defined $states) {
      if (scalar($states)) {
         # check duplicate states
         if ($self->states($states) < 0) {
            $self->throw("Duplicate states!\n");
         }
      }
      else {
         $self->throw("We don't support list of states in this version.\n");
      }
   }

   $self->{'hmm'} = new Bio::Ext::HMM::HMM($symbols, $states);
   return $self;
}
sub likelihood {
   my ($self, $seq) = @_;
   my $valid_symbols;

   if( ! defined $seq) {
      $self->warn("Cannot calculate without supply an observation sequence!");
      return undef;
   }
   my $s = $self->{'symbols'};
   $_ = $seq;
   $valid_symbols = eval "tr/$s//;"; 
   if ($valid_symbols != length($seq)) {
      $self->throw("Observation Sequence contains characters that is not in the
                    alphabet of observation symbols!\n");
   }
   return Bio::Ext::HMM->HMM_likelihood($self->{'hmm'}, $seq);
}
sub statistical_training {
   my ($self, $seqs, $hss) = @_;
   my $valid_symbols;
   my $seq_cnt, $hs_cnt;
   my $i;

   if( ! defined $seqs or ! defined $hss) {
      $self->warn("Cannot calculate without supply an observation and a hidden state sequence!");
      return undef;
   }
   $seq_cnt = @{$seqs};
   $hs_cnt = @{$seqs};
   if ($seq_cnt != $hs_cnt) {
      $self->throw("There must be the same number of observation sequences and 
                    hidden state sequences!\n");
   }
   for ($i = 0; $i < $seq_cnt; ++$i) {
      if (length(@{$seqs}[$i]) != length(@{$hss}[$i])) {
         $self->throw("The corresponding observation sequences and hidden state sequences must be of the same length!\n");
      }
   }
   foreach $seq (@{$seqs}) {
      my $s = $self->{'symbols'};
      $_ = $seq;
      $valid_symbols = eval "tr/$s//;"; 
      if ($valid_symbols != length($seq)) {
         $self->throw("Observation Sequence contains characters that is not in the
                alphabet of observation symbols!\n");
      }
   }
   foreach $seq (@{$hss}) {
      my $s = $self->{'states'};
      $_ = $seq;
      $valid_symbols = eval "tr/$s//;"; 
      if ($valid_symbols != length($seq)) {
         $self->throw("Hidden State Sequence contains characters that is not in the
                alphabet of hidden states!\n");
      }
   }
   Bio::Ext::HMM->HMM_statistical_training($self->{'hmm'}, $seqs, $hss);
}
sub baum_welch_training {
   my ($self, $seqs) = @_;
   my $valid_symbols;

   if( ! defined $seqs) {
      $self->warn("Cannot calculate without supply an observation sequence!");
      return undef;
   }
   foreach $seq (@{$seqs}) {
      my $s = $self->{'symbols'};
      $_ = $seq;
      $valid_symbols = eval "tr/$s//;"; 
      if ($valid_symbols != length($seq)) {
         $self->throw("Observation Sequence contains characters that is not in the
                alphabet of observation symbols!\n");
      }
   }
   Bio::Ext::HMM->HMM_baum_welch_training($self->{'hmm'}, $seqs);
}
sub viterbi {
   my ($self, $seq) = @_;
   my $valid_symbols;

   if( ! defined $seq) {
      $self->warn("Cannot calculate without supply an observation sequence!");
      return undef;
   }
   my $s = $self->{'symbols'};
   $_ = $seq;
   $valid_symbols = eval "tr/$s//;"; 
   if ($valid_symbols != length($seq)) {
      $self->throw("Observation Sequence contains characters that is not in the
             alphabet of observation symbols!\n");
   }
   return Bio::Ext::HMM->HMM_viterbi($self->{'hmm'}, $seq);
}
sub symbols {
   my ($self,$val) = @_;
   my %alphabets = ();
   my $c;

   if ( defined $val ) {
# find duplicate
      
      for ($i = 0; $i < length($val); ++$i) {
         $c = substr($val, $i, 1);
         if (defined $alphabets{$c}) {
            $self->throw("Can't have duplicate symbols!");
         }
         else {
            $alphabets{$c} = 1;
         }
      }
      $self->{'symbols'} = $val;
   }
   return $self->{'symbols'};
}
sub states {
   my ($self,$val) = @_;
   my %alphabets = ();
   my $c;

   if ( defined $val ) {
# find duplicate
      
      for ($i = 0; $i < length($val); ++$i) {
         $c = substr($val, $i, 1);
         if (defined $alphabets{$c}) {
            $self->throw("Can't have duplicate states!");
         }
         else {
            $alphabets{$c} = 1;
         }
      }
      $self->{'states'} = $val;
   }
   return $self->{'states'};
}
sub init_prob {
   my ($self, $init) = @_;
   my $i;
   my @A;

   if (defined $init) {
      if (ref($init)) {
         my $size = @{$init};
         my $sum = 0.0;
         foreach (@{$init}) {
            $sum += $_;
         }
         if ($sum != 1.0) {
            $self->throw("The sum of initial probability array must be 1.0!\n");
         }
         if ($size != length($self->{'states'})) {
            $self->throw("The size of init array $size is different from the number of HMM's hidden states!\n");
         }
         for ($i = 0; $i < $size; ++$i) {
            Bio::Ext::HMM::HMM->set_init_entry($self->{'hmm'}, substr($self->{'states'}, $i, 1), @{$init}[$i]);
         }
      }
      else {
         $self->throw("Initial Probability array must be a reference!\n");
      }
   }
   else {
      for ($i = 0; $i < length($self->{'states'}); ++$i) {
         $A[$i] = Bio::Ext::HMM::HMM->get_init_entry($self->{'hmm'}, substr($self->{'states'}, $i, 1));
      }
      return\@ A;
   }
}
sub transition_prob {
   my ($self, $matrix) = @_;
   my $i, $j;
   my @A;

   if (defined $matrix) {
      if ($matrix->isa('Bio::Matrix::Scoring')) {
         my $row = join("", $matrix->row_names);
         my $col = join("", $matrix->column_names);
         if ($row ne $self->{'states'}) {
            $self->throw("Names of the rows ($row) is different from the states of HMM " . $self->{'states'});
         } 
         if ($col ne $self->{'states'}) {
            $self->throw("Names of the columns ($col) is different from the states of HMM " . $self->{'states'});
         }
         for ($i = 0; $i < length($self->{'states'}); ++$i) {
            my $sum = 0.0;
            my $a = substr($self->{'states'}, $i, 1);
            for ($j = 0; $j < length($self->{'states'}); ++$j) {
               my $b = substr($self->{'states'}, $j, 1);
               $sum += $matrix->entry($a, $b);
            }
            if ($sum != 1.0) {
               $self->throw("Sum of probabilities for each from-state must be 1.0!\n");
            }
         }
         for ($i = 0; $i < length($self->{'states'}); ++$i) {
            my $a = substr($self->{'states'}, $i, 1);
            for ($j = 0; $j < length($self->{'states'}); ++$j) {
               my $b = substr($self->{'states'}, $j, 1);
               Bio::Ext::HMM::HMM->set_a_entry($self->{'hmm'}, $a, $b, $matrix->entry($a, $b));
            }
         }
      }
      else {
         $self->throw("Transition Probability matrix must be of type Bio::Matrix::Scoring.\n");
      }
   }
   else {
      for ($i = 0; $i < length($self->{'states'}); ++$i) {
         for ($j = 0; $j < length($self->{'states'}); ++$j) {
            $A[$i][$j] = Bio::Ext::HMM::HMM->get_a_entry($self->{'hmm'}, substr($self->{'states'}, $i, 1), substr($self->{'states'}, $j, 1));
         }
      }
      my @rows = split(//, $self->{'states'});
      return $matrix = new Bio::Matrix::Scoring(-values =>\@ A, -rownames =>\@ rows, -colnames =>\@ rows);
   }
}
sub emission_prob {
   my ($self, $matrix) = @_;
   my $i, $j;
   my @A;

   if (defined $matrix) {
      if ($matrix->isa('Bio::Matrix::Scoring')) {
         my $row = join("", $matrix->row_names);
         my $col = join("", $matrix->column_names);
         if ($row ne $self->{'states'}) {
            $self->throw("Names of the rows ($row) is different from the states of HMM " . $self->{'states'});
         } 
         if ($col ne $self->{'symbols'}) {
            $self->throw("Names of the columns ($col) is different from the symbols of HMM " . $self->{'symbols'});
         }
         for ($i = 0; $i < length($self->{'states'}); ++$i) {
            my $sum = 0.0;
            my $a = substr($self->{'states'}, $i, 1);
            for ($j = 0; $j < length($self->{'symbols'}); ++$j) {
               my $b = substr($self->{'symbols'}, $j, 1);
               $sum += $matrix->entry($a, $b);
            }
            if ($sum != 1.0) {
               $self->throw("Sum of probabilities for each state must be 1.0!\n");
            }
         }
         for ($i = 0; $i < length($self->{'states'}); ++$i) {
            my $a = substr($self->{'states'}, $i, 1);
            for ($j = 0; $j < length($self->{'symbols'}); ++$j) {
               my $b = substr($self->{'symbols'}, $j, 1);
               Bio::Ext::HMM::HMM->set_e_entry($self->{'hmm'}, $a, $b, $matrix->entry($a, $b));
            }
         }
      }
      else {
         $self->throw("Emission Probability matrix must be of type Bio::Matrix::Scoring.\n");
      }
   }
   else {
      for ($i = 0; $i < length($self->{'states'}); ++$i) {
         for ($j = 0; $j < length($self->{'symbols'}); ++$j) {
            $A[$i][$j] = Bio::Ext::HMM::HMM->get_e_entry($self->{'hmm'}, substr($self->{'states'}, $i, 1), substr($self->{'symbols'}, $j, 1));
         }
      }
      my @rows = split(//, $self->{'states'});
      my @cols = split(//, $self->{'symbols'});
      return $matrix = new Bio::Matrix::Scoring(-values =>\@ A, -rownames =>\@ rows, -colnames =>\@ cols);
   }
}