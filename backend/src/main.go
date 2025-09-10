package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/gofiber/fiber/v2"
	_ "github.com/mattn/go-sqlite3"
)

var db *sql.DB

func main() {
	var err error
	db, err = sql.Open("sqlite3", "./tagwerk.db")
	if err != nil {
		panic(err)
	}
	defer db.Close()

	// Create tables if not exist (add users table for auth)
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS users (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			email TEXT UNIQUE NOT NULL,
			password TEXT NOT NULL  -- Hash in production!
		);
		CREATE TABLE IF NOT EXISTS todos (
			id INTEGER PRIMARY KEY,
			title TEXT NOT NULL,
			description TEXT NOT NULL,
			is_done INTEGER NOT NULL,
			due_date INTEGER,
			completed_at INTEGER,
			group_id INTEGER,
			order_ INTEGER NOT NULL,
			subtasks TEXT NOT NULL,
			saved_due_date INTEGER,
			created_at INTEGER NOT NULL,
			user_id INTEGER NOT NULL
		);
		CREATE TABLE IF NOT EXISTS groups (
			id INTEGER PRIMARY KEY,
			name TEXT NOT NULL,
			color INTEGER NOT NULL,
			user_id INTEGER NOT NULL
		);
		CREATE TABLE IF NOT EXISTS settings (
			id INTEGER PRIMARY KEY,
			key TEXT NOT NULL UNIQUE,
			value TEXT,
			user_id INTEGER NOT NULL
		);
	`)
	if err != nil {
		panic(err)
	}

	app := fiber.New()

	// Basic auth endpoints (in production, use bcrypt/JWT properly)
	app.Post("/auth/signup", signup)
	app.Post("/auth/signin", signin)

	// Protected routes (add middleware for auth in production)
	app.Get("/todos", getTodos)
	app.Post("/todos", upsertTodos)
	app.Delete("/todos/:id", deleteTodo)

	app.Get("/groups", getGroups)
	app.Post("/groups", upsertGroups)
	app.Delete("/groups/:id", deleteGroup)

	app.Get("/settings", getSettings)
	app.Post("/settings", upsertSettings)

	app.Listen(":8080")
}

type User struct {
	ID       int    `json:"id"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

func signup(c *fiber.Ctx) error {
	var user User
	if err := c.BodyParser(&user); err != nil {
		return c.Status(400).SendString("Invalid request")
	}
	// Hash password in production
	_, err := db.Exec("INSERT INTO users (email, password) VALUES (?, ?)", user.Email, user.Password)
	if err != nil {
		return c.Status(500).SendString("Signup failed")
	}
	return c.JSON(map[string]string{"token": "dummy-token-" + user.Email})  // Use JWT in production
}

func signin(c *fiber.Ctx) error {
	var user User
	if err := c.BodyParser(&user); err != nil {
		return c.Status(400).SendString("Invalid request")
	}
	var dbPass string
	err := db.QueryRow("SELECT password FROM users WHERE email = ?", user.Email).Scan(&dbPass)
	if err != nil || dbPass != user.Password {
		return c.Status(401).SendString("Invalid credentials")
	}
	return c.JSON(map[string]string{"token": "dummy-token-" + user.Email})
}

// Placeholder user_id; extract from token in production
func getUserID(c *fiber.Ctx) int {
	return 1  // Dummy; implement auth middleware
}

// In main.go, replace getTodos function
func getTodos(c *fiber.Ctx) error {
    userID := getUserID(c)
    rows, err := db.Query("SELECT id, title, description, is_done, due_date, completed_at, group_id, order_, subtasks, saved_due_date, created_at, user_id FROM todos WHERE user_id = ?", userID)
    if err != nil {
        return c.Status(500).SendString("Error")
    }
    defer rows.Close()
    var todos []map[string]interface{}
    for rows.Next() {
        var id, isDone, order, createdAt, userID int
        var title, description, subtasks string
        var dueDate, completedAt, groupID, savedDueDate sql.NullInt64 // Use NullInt64 for nullable fields
        err = rows.Scan(&id, &title, &description, &isDone, &dueDate, &completedAt, &groupID, &order, &subtasks, &savedDueDate, &createdAt, &userID)
        if err != nil {
            return c.Status(500).SendString("Error")
        }
        todo := map[string]interface{}{
            "id":             id,
            "title":          title,
            "description":    description,
            "is_done":        isDone,
            "due_date":       dueDate.Int64,
            "completed_at":   completedAt.Int64,
            "group_id":       groupID.Int64,
            "order_":         order,
            "subtasks":       subtasks,
            "saved_due_date": savedDueDate.Int64,
            "created_at":     createdAt,
            "user_id":        userID,
        }
        if !dueDate.Valid {
            todo["due_date"] = nil
        }
        if !completedAt.Valid {
            todo["completed_at"] = nil
        }
        if !groupID.Valid {
            todo["group_id"] = nil
        }
        if !savedDueDate.Valid {
            todo["saved_due_date"] = nil
        }
        todos = append(todos, todo)
    }
    return c.JSON(todos)
}

func upsertTodos(c *fiber.Ctx) error {
	var todos []map[string]interface{}
	if err := json.Unmarshal(c.Body(), &todos); err != nil {
		return c.Status(400).SendString("Invalid request")
	}
	tx, err := db.Begin()
	if err != nil {
		return c.Status(500).SendString("Error")
	}
	stmt, err := tx.Prepare("INSERT OR REPLACE INTO todos (id, title, description, is_done, due_date, completed_at, group_id, order_, subtasks, saved_due_date, created_at, user_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
	if err != nil {
		tx.Rollback()
		return c.Status(500).SendString("Error")
	}
	defer stmt.Close()
	for _, todo := range todos {
		_, err := stmt.Exec(todo["id"], todo["title"], todo["description"], todo["is_done"], todo["due_date"], todo["completed_at"], todo["group_id"], todo["order_"], todo["subtasks"], todo["saved_due_date"], todo["created_at"], todo["user_id"])
		if err != nil {
			tx.Rollback()
			return c.Status(500).SendString("Error")
		}
	}
	tx.Commit()
	return c.SendStatus(200)
}

func deleteTodo(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))
	userID := getUserID(c)
	_, err := db.Exec("DELETE FROM todos WHERE id = ? AND user_id = ?", id, userID)
	if err != nil {
		return c.Status(500).SendString("Error")
	}
	return c.SendStatus(200)
}

// Similar for groups and settings (implement getGroups, upsertGroups, deleteGroup, getSettings, upsertSettings)
func getGroups(c *fiber.Ctx) error {
    userID := getUserID(c)
    rows, err := db.Query("SELECT id, name, color, user_id FROM groups WHERE user_id = ?", userID)
    if err != nil {
        return c.Status(500).SendString("Error")
    }
    defer rows.Close()
    var groups []map[string]interface{}
    for rows.Next() {
        var id, color, userID int
        var name string
        err = rows.Scan(&id, &name, &color, &userID)
        if err != nil {
            return c.Status(500).SendString("Error")
        }
        group := map[string]interface{}{
            "id":       id,
            "name":     name,
            "color":    color,
            "user_id":  userID,
        }
        groups = append(groups, group)
    }
    return c.JSON(groups)
}

func upsertGroups(c *fiber.Ctx) error {
	// Similar to upsertTodos
	var groups []map[string]interface{}
	if err := json.Unmarshal(c.Body(), &groups); err != nil {
		return c.Status(400).SendString("Invalid request")
	}
	tx, err := db.Begin()
	if err != nil {
		return c.Status(500).SendString("Error")
	}
	stmt, err := tx.Prepare("INSERT OR REPLACE INTO groups (id, name, color, user_id) VALUES (?, ?, ?, ?)")
	if err != nil {
		tx.Rollback()
		return c.Status(500).SendString("Error")
	}
	defer stmt.Close()
	for _, group := range groups {
		_, err := stmt.Exec(group["id"], group["name"], group["color"], group["user_id"])
		if err != nil {
			tx.Rollback()
			return c.Status(500).SendString("Error")
		}
	}
	tx.Commit()
	return c.SendStatus(200)
}

func deleteGroup(c *fiber.Ctx) error {
	id, _ := strconv.Atoi(c.Params("id"))
	userID := getUserID(c)
	_, err := db.Exec("DELETE FROM groups WHERE id = ? AND user_id = ?", id, userID)
	if err != nil {
		return c.Status(500).SendString("Error")
	}
	return c.SendStatus(200)
}

func getSettings(c *fiber.Ctx) error {
    userID := getUserID(c)
    rows, err := db.Query("SELECT id, key, value, user_id FROM settings WHERE user_id = ?", userID)
    if err != nil {
        return c.Status(500).SendString("Error")
    }
    defer rows.Close()
    var settings []map[string]interface{}
    for rows.Next() {
        var id, userID int
        var key, value sql.NullString // Use NullString for nullable value
        err = rows.Scan(&id, &key, &value, &userID)
        if err != nil {
            return c.Status(500).SendString("Error")
        }
        setting := map[string]interface{}{
            "id":       id,
            "key":      key,
            "value":    value.String,
            "user_id":  userID,
        }
        if !value.Valid {
            setting["value"] = nil
        }
        settings = append(settings, setting)
    }
    return c.JSON(settings)
}

func upsertSettings(c *fiber.Ctx) error {
	var settings []map[string]interface{}
	if err := json.Unmarshal(c.Body(), &settings); err != nil {
		return c.Status(400).SendString("Invalid request")
	}
	tx, err := db.Begin()
	if err != nil {
		return c.Status(500).SendString("Error")
	}
	stmt, err := tx.Prepare("INSERT OR REPLACE INTO settings (id, key, value, user_id) VALUES (?, ?, ?, ?)")
	if err != nil {
		tx.Rollback()
		return c.Status(500).SendString("Error")
	}
	defer stmt.Close()
	for _, setting := range settings {
		_, err := stmt.Exec(setting["id"], setting["key"], setting["value"], setting["user_id"])
		if err != nil {
			tx.Rollback()
			return c.Status(500).SendString("Error")
		}
	}
	tx.Commit()
	return c.SendStatus(200)
}