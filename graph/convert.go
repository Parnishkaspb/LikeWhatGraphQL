package graph

import (
	"time"

	likewhat "github.com/Parnishkaspb/LikeWhat/pkg/like_what"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// protoTime конвертирует proto Timestamp в RFC3339-строку.
func protoTime(ts *timestamppb.Timestamp) string {
	if ts == nil || !ts.IsValid() {
		return ""
	}
	return ts.AsTime().UTC().Format(time.RFC3339)
}

// protoManufacture конвертирует proto Manufacture в GraphQL-модель.
func protoManufacture(m *likewhat.Manufacture) *Manufacture {
	if m == nil {
		return nil
	}
	deletedAt := protoTime(m.DeletedAt)
	return &Manufacture{
		ID:        m.Id,
		Name:      m.Name,
		CreatedAt: protoTime(m.CreatedAt),
		UpdatedAt: protoTime(m.UpdatedAt),
		DeletedAt: &deletedAt,
	}
}

// protoTobacco конвертирует proto Tobacco в GraphQL-модель.
func protoTobacco(t *likewhat.Tobacco) *Tobacco {
	if t == nil {
		return nil
	}
	deletedAt := protoTime(t.DeletedAt)
	return &Tobacco{
		ID:          t.Id,
		Taste:       t.Taste,
		Photo:       t.Photo,
		Manufacture: protoManufacture(t.Manufacture),
		CreatedAt:   protoTime(t.CreatedAt),
		UpdatedAt:   protoTime(t.UpdatedAt),
		DeletedAt:   &deletedAt,
	}
}

// protoUser конвертирует proto User в GraphQL-модель.
func protoUser(u *likewhat.User) *User {
	if u == nil {
		return nil
	}
	return &User{
		ID:         int(u.Id),
		TelegramID: int(u.TelegramId),
		NickName:   u.NickName,
		Name:       u.Name,
	}
}

// protoRecipe конвертирует proto Recipe в GraphQL-модель.
func protoRecipe(r *likewhat.Recipe) *Recipe {
	if r == nil {
		return nil
	}
	deletedAt := protoTime(r.DeletedAt)

	tobaccos := make([]*RecipeTobacco, 0, len(r.Tobaccos))
	for _, t := range r.Tobaccos {
		tobaccos = append(tobaccos, &RecipeTobacco{
			TobaccoID: t.TobaccoId,
			Percent:   t.Percent,
		})
	}

	steps := make([]*RecipeStep, 0, len(r.Steps))
	for _, s := range r.Steps {
		var tobaccoID *string
		if s.TobaccoId != "" {
			tobaccoID = &s.TobaccoId
		}
		steps = append(steps, &RecipeStep{
			StepNumber: int(s.StepNumber),
			TobaccoID:  tobaccoID,
			WhatDo:     s.WhatDo,
		})
	}

	return &Recipe{
		ID:        r.Id,
		UserID:    int(r.UserId),
		Title:     r.Title,
		Tobaccos:  tobaccos,
		Steps:     steps,
		CreatedAt: protoTime(r.CreatedAt),
		UpdatedAt: protoTime(r.UpdatedAt),
		DeletedAt: &deletedAt,
	}
}
