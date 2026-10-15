package core

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
)

// ParameterDriver is optional. Drivers must send values separately from SQL.
type ParameterDriver interface {
	QueryParams(context.Context, string, []any) (ResultStream, error)
}

// ParameterValue keeps textual input exact, distinguishing NULL from empty text.
type ParameterValue struct {
	Text string `msgpack:"text"`
	Null bool   `msgpack:"is_null"`
}

type NamedQuery struct {
	SQL   string
	Names []string
}

func nameStart(c byte) bool { return c == '_' || c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' }
func namePart(c byte) bool  { return nameStart(c) || c >= '0' && c <= '9' }

// CompileNamed translates only placeholder tokens, never values. Quoted strings,
// identifiers, dollar quotes, casts and nested comments remain byte-for-byte intact.
func CompileNamed(query string) (*NamedQuery, error) {
	var sql strings.Builder
	names := []string{}
	positions := map[string]int{}
	statements, pending, positional := 0, false, false
	for i := 0; i < len(query); {
		start := i
		switch {
		case strings.HasPrefix(query[i:], "--"):
			for i < len(query) && query[i] != '\n' {
				i++
			}
		case strings.HasPrefix(query[i:], "/*"):
			i += 2
			depth := 1
			for i < len(query) && depth > 0 {
				if strings.HasPrefix(query[i:], "/*") {
					depth++
					i += 2
				} else if strings.HasPrefix(query[i:], "*/") {
					depth--
					i += 2
				} else {
					i++
				}
			}
			if depth > 0 {
				return nil, errors.New("unterminated SQL comment")
			}
		case query[i] == '\'' || query[i] == '"':
			quote := query[i]
			escaped := quote == '\'' && i > 0 && (query[i-1] == 'E' || query[i-1] == 'e') && (i == 1 || !namePart(query[i-2]))
			pending = true
			i++
			closed := false
			for i < len(query) {
				if escaped && query[i] == '\\' && i+1 < len(query) {
					i += 2
					continue
				}
				if query[i] == quote {
					i++
					if i < len(query) && query[i] == quote {
						i++
						continue
					}
					closed = true
					break
				}
				i++
			}
			if !closed {
				return nil, errors.New("unterminated SQL quote")
			}
		case query[i] == '$':
			end := i + 1
			if end < len(query) && query[end] >= '0' && query[end] <= '9' {
				positional = true
				for end < len(query) && query[end] >= '0' && query[end] <= '9' {
					end++
				}
				i = end
			} else {
				if end < len(query) && nameStart(query[end]) {
					for end < len(query) && namePart(query[end]) {
						end++
					}
				}
				if end < len(query) && query[end] == '$' {
					delimiter := query[i : end+1]
					close := strings.Index(query[end+1:], delimiter)
					if close < 0 {
						return nil, errors.New("unterminated SQL dollar quote")
					}
					i = end + 1 + close + len(delimiter)
				} else {
					i++
				}
			}
			pending = true
		case query[i] == ':' && i+1 < len(query) && (query[i+1] == ':' || query[i+1] == '='):
			i += 2
			pending = true
		case query[i] == ':' && i+1 < len(query) && nameStart(query[i+1]):
			i += 2
			for i < len(query) && namePart(query[i]) {
				i++
			}
			name := query[start+1 : i]
			position, exists := positions[name]
			if !exists {
				names = append(names, name)
				position = len(names)
				positions[name] = position
			}
			sql.WriteString("$" + strconv.Itoa(position))
			pending = true
			continue
		case query[i] == ';':
			if pending {
				statements++
				pending = false
			}
			i++
		case nameStart(query[i]) || query[i] >= 0x80:
			i++
			for i < len(query) && (namePart(query[i]) || query[i] == '$' || query[i] >= 0x80) {
				i++
			}
			pending = true
		default:
			if query[i] != ' ' && query[i] != '\t' && query[i] != '\r' && query[i] != '\n' {
				pending = true
			}
			i++
		}
		sql.WriteString(query[start:i])
	}
	if pending {
		statements++
	}
	if len(names) > 0 {
		if statements != 1 {
			return nil, errors.New("bound parameters require one SQL statement; select a statement or run the statement under the cursor")
		}
		if positional {
			return nil, errors.New("cannot mix named parameters and PostgreSQL $n placeholders")
		}
		if len(names) > 65535 {
			return nil, errors.New("PostgreSQL supports at most 65535 distinct parameters")
		}
	}
	return &NamedQuery{SQL: sql.String(), Names: names}, nil
}

func (c *Connection) ParameterNames(query string) ([]string, error) {
	plan, err := CompileNamed(query)
	if err != nil {
		return nil, err
	}
	if len(plan.Names) > 0 {
		if _, ok := c.driver.(ParameterDriver); !ok {
			return nil, errors.New("native parameter binding is not supported for this database driver")
		}
	}
	return plan.Names, nil
}

func (c *Connection) ExecuteBound(query string, values map[string]ParameterValue, onEvent func(CallState, *Call)) (*Call, error) {
	plan, err := CompileNamed(query)
	if err != nil {
		return nil, err
	}
	if len(plan.Names) == 0 && len(values) == 0 {
		return c.Execute(query, onEvent), nil
	}
	driver, ok := c.driver.(ParameterDriver)
	if !ok {
		return nil, errors.New("native parameter binding is not supported for this database driver")
	}
	args := make([]any, len(plan.Names))
	for i, name := range plan.Names {
		value, exists := values[name]
		if !exists {
			return nil, fmt.Errorf("missing parameter :%s", name)
		}
		if !value.Null {
			args[i] = value.Text
		}
	}
	if len(values) != len(plan.Names) {
		return nil, errors.New("unexpected parameter values supplied")
	}
	// Only the original SQL is kept in call history; values stay out of it.
	return newCallFromExecutor(func(ctx context.Context) (ResultStream, error) {
		return driver.QueryParams(ctx, plan.SQL, args)
	}, query, onEvent), nil
}
