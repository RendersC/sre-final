package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"math/rand"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

const serviceName = "ecom-api"

var (
	httpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests processed, partitioned by route, method and status.",
		},
		[]string{"route", "method", "status"},
	)

	httpRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "Histogram of HTTP request latencies in seconds.",
			Buckets: []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5},
		},
		[]string{"route", "method"},
	)

	httpInflightRequests = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "http_inflight_requests",
			Help: "Number of HTTP requests currently being processed.",
		},
	)

	ordersCreatedTotal = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "orders_created_total",
			Help: "Total number of orders successfully created.",
		},
	)

	ordersFailedTotal = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "orders_failed_total",
			Help: "Total number of order creation failures.",
		},
	)

	productsCatalogSize = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "products_catalog_size",
			Help: "Current number of products in the in-memory catalog.",
		},
	)
)

type Product struct {
	ID    int     `json:"id"`
	Name  string  `json:"name"`
	Price float64 `json:"price"`
	Stock int     `json:"stock"`
}

type Order struct {
	ID        int       `json:"id"`
	ProductID int       `json:"product_id"`
	Quantity  int       `json:"quantity"`
	Total     float64   `json:"total"`
	CreatedAt time.Time `json:"created_at"`
}

type store struct {
	mu       sync.RWMutex
	products map[int]Product
	orders   map[int]Order
	orderSeq int64
}

func newStore() *store {
	s := &store{
		products: make(map[int]Product),
		orders:   make(map[int]Order),
	}
	seed := []Product{
		{ID: 1, Name: "Mechanical Keyboard", Price: 129.99, Stock: 42},
		{ID: 2, Name: "Wireless Mouse", Price: 49.50, Stock: 120},
		{ID: 3, Name: "27\" 4K Monitor", Price: 549.00, Stock: 15},
		{ID: 4, Name: "USB-C Hub", Price: 39.99, Stock: 200},
		{ID: 5, Name: "Noise-Cancelling Headphones", Price: 299.00, Stock: 30},
	}
	for _, p := range seed {
		s.products[p.ID] = p
	}
	productsCatalogSize.Set(float64(len(s.products)))
	return s
}

func (s *store) listProducts() []Product {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Product, 0, len(s.products))
	for _, p := range s.products {
		out = append(out, p)
	}
	return out
}

func (s *store) getProduct(id int) (Product, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	p, ok := s.products[id]
	return p, ok
}

func (s *store) createOrder(productID, qty int) (Order, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, ok := s.products[productID]
	if !ok {
		return Order{}, errors.New("product not found")
	}
	if qty <= 0 {
		return Order{}, errors.New("quantity must be positive")
	}
	if p.Stock < qty {
		return Order{}, errors.New("insufficient stock")
	}
	p.Stock -= qty
	s.products[productID] = p

	id := int(atomic.AddInt64(&s.orderSeq, 1))
	o := Order{
		ID:        id,
		ProductID: productID,
		Quantity:  qty,
		Total:     p.Price * float64(qty),
		CreatedAt: time.Now().UTC(),
	}
	s.orders[id] = o
	return o, nil
}

type metricsResponseWriter struct {
	http.ResponseWriter
	status int
}

func (w *metricsResponseWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

func instrument(route string, h http.HandlerFunc) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		httpInflightRequests.Inc()
		defer httpInflightRequests.Dec()

		start := time.Now()
		mw := &metricsResponseWriter{ResponseWriter: w, status: http.StatusOK}
		h.ServeHTTP(mw, r)

		duration := time.Since(start).Seconds()
		httpRequestDuration.WithLabelValues(route, r.Method).Observe(duration)
		httpRequestsTotal.WithLabelValues(route, r.Method, strconv.Itoa(mw.status)).Inc()
	})
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func main() {
	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8080"
	}
	ready := atomic.Bool{}

	st := newStore()
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))

	mux := http.NewServeMux()

	mux.Handle("/metrics", promhttp.Handler())

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	mux.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
		if !ready.Load() {
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte("starting"))
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ready"))
	})

	mux.Handle("/api/products", instrument("/api/products", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
			return
		}
		writeJSON(w, http.StatusOK, st.listProducts())
	}))

	mux.Handle("/api/products/", instrument("/api/products/{id}", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
			return
		}
		idStr := strings.TrimPrefix(r.URL.Path, "/api/products/")
		id, err := strconv.Atoi(idStr)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid id"})
			return
		}
		p, ok := st.getProduct(id)
		if !ok {
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "product not found"})
			return
		}
		writeJSON(w, http.StatusOK, p)
	}))

	mux.Handle("/api/orders", instrument("/api/orders", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
			return
		}
		var req struct {
			ProductID int `json:"product_id"`
			Quantity  int `json:"quantity"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			ordersFailedTotal.Inc()
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
			return
		}
		o, err := st.createOrder(req.ProductID, req.Quantity)
		if err != nil {
			ordersFailedTotal.Inc()
			writeJSON(w, http.StatusUnprocessableEntity, map[string]string{"error": err.Error()})
			return
		}
		ordersCreatedTotal.Inc()
		writeJSON(w, http.StatusCreated, o)
	}))

	// Synthetic CPU load endpoint — helps demonstrate HPA scaling.
	mux.Handle("/api/work", instrument("/api/work", func(w http.ResponseWriter, r *http.Request) {
		msStr := r.URL.Query().Get("ms")
		ms, _ := strconv.Atoi(msStr)
		if ms <= 0 {
			ms = 50
		}
		if ms > 2000 {
			ms = 2000
		}
		deadline := time.Now().Add(time.Duration(ms) * time.Millisecond)
		x := 0
		for time.Now().Before(deadline) {
			x += rng.Intn(1000)
		}
		writeJSON(w, http.StatusOK, map[string]int{"work_ms": ms, "result": x})
	}))

	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		// Simulate startup warmup before marking ready.
		time.Sleep(2 * time.Second)
		ready.Store(true)
		log.Printf("%s: ready to serve traffic", serviceName)
	}()

	go func() {
		log.Printf("%s: listening on %s", serviceName, addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server error: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop
	log.Printf("%s: shutdown signal received", serviceName)

	ready.Store(false)
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("graceful shutdown failed: %v", err)
	}
	log.Printf("%s: bye", serviceName)
}
