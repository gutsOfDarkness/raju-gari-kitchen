package logger

import (
	"context"
	"log/slog"
	"os"
	"time"
)

var Log *Logger

type Logger struct {
	*slog.Logger
}

func Init() {
	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	})
	Log = &Logger{slog.New(handler)}
}

// NewLogger creates a new logger instance (useful for fallbacks)
func NewLogger() *Logger {
    if Log != nil {
        return Log
    }
	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	})
	return &Logger{slog.New(handler)}
}

// Global variable accessors
func Info(msg string, args ...any) {
    if Log != nil {
	    Log.Info(msg, args...)
    }
}

func Error(msg string, args ...any) {
    if Log != nil {
	    Log.Error(msg, args...)
    }
}

func Debug(msg string, args ...any) {
    if Log != nil {
	    Log.Debug(msg, args...)
    }
}

func Warn(msg string, args ...any) {
    if Log != nil {
	    Log.Warn(msg, args...)
    }
}

func Fatal(msg string, args ...any) {
    if Log != nil {
        Log.Error(msg, args...)
        os.Exit(1)
    }
}

// WithRequestID creates a child logger with request ID
func (l *Logger) WithRequestID(requestID string) *Logger {
	return &Logger{l.Logger.With(slog.String("request_id", requestID))}
}

// Fatal logs at error level and exits
func (l *Logger) Fatal(msg string, args ...any) {
    l.Error(msg, args...)
    os.Exit(1)
}

// WithFields creates a child logger with structured fields (compatibility)
// Accepts map[string]interface{} or just args
func (l *Logger) WithFields(fields map[string]interface{}) *Logger {
    var args []any
    for k, v := range fields {
        args = append(args, slog.Any(k, v))
    }
	return &Logger{l.Logger.With(args...)}
}


// LogPanic logs a panic with stack trace
func (l *Logger) LogPanic(r interface{}, stack []byte) {
	l.Error("Panic recovered",
		slog.Any("recover", r),
		slog.String("stack_trace", string(stack)),
	)
}

// RequestLogEntry defines the structure for request logging
type RequestLogEntry struct {
	Timestamp  time.Time
	RequestID  string
	Method     string
	Path       string
	StatusCode int
	Latency    time.Duration
	ClientIP   string
	UserAgent  string
	Error      string
}

// LogRequest logs a request completion
func (l *Logger) LogRequest(entry RequestLogEntry) {
	level := slog.LevelInfo
	if entry.StatusCode >= 500 {
		level = slog.LevelError
	} else if entry.StatusCode >= 400 {
		level = slog.LevelWarn
	}

	l.Log(context.Background(), level, "Request completed",
		slog.String("request_id", entry.RequestID),
		slog.String("method", entry.Method),
		slog.String("path", entry.Path),
		slog.Int("status", entry.StatusCode),
		slog.Duration("latency", entry.Latency),
		slog.String("ip", entry.ClientIP),
		slog.String("user_agent", entry.UserAgent),
		slog.String("error", entry.Error),
	)
}
