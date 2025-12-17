(defn main [& args]
  (print "Hello from quickbin!")
  (print "Arguments:")
  (each arg args
    (print "  " arg))
  (print "Janet v" janet/version))
