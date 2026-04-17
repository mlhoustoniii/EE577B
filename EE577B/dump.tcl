database -open ncsim -shm -into ncsim.shm -default
probe -create tb_gold_mesh -shm -all -depth all
run
exit
