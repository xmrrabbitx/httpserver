<?php
print("served by http assembly!\n\n");
$start_time = microtime(true);

function fibonacci($n) {
	    if ($n <= 1) {
		            return $n;
			        } else {
					        return fibonacci($n - 1) + fibonacci($n - 2);
						    }
}


$number = 35;
$fib_result = fibonacci($number);


$end_time = microtime(true);


$execution_time = $end_time - $start_time;


echo "Fibonacci number at position $number is: $fib_result\n";
echo "Execution time: $execution_time seconds\n";
?>

