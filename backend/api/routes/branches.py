from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from backend.core.database import get_db
from backend.models.branch import Branch, Warehouse
from backend.schemas.branch import BranchCreate, BranchUpdate, BranchResponse, WarehouseCreate, WarehouseResponse
from backend.api.dependencies import get_current_user, require_admin, require_branch_manager_or_above

router = APIRouter()


# ── Branches ─────────────────────────────────────────────────────────────────

@router.get("/", response_model=List[BranchResponse])
def list_branches(db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    return db.query(Branch).filter(Branch.is_active == True).all()


@router.post("/", response_model=BranchResponse)
def create_branch(data: BranchCreate, db: Session = Depends(get_db), current_user=Depends(require_admin)):
    branch = Branch(**data.model_dump())
    db.add(branch)
    db.commit()
    db.refresh(branch)
    return branch


@router.get("/{branch_id}", response_model=BranchResponse)
def get_branch(branch_id: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(404, "Branch not found")
    return branch


@router.put("/{branch_id}", response_model=BranchResponse)
def update_branch(branch_id: int, data: BranchUpdate, db: Session = Depends(get_db), current_user=Depends(require_admin)):
    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(404, "Branch not found")
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(branch, k, v)
    db.commit()
    db.refresh(branch)
    return branch


@router.delete("/{branch_id}")
def delete_branch(branch_id: int, db: Session = Depends(get_db), current_user=Depends(require_admin)):
    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(404, "Branch not found")
    branch.is_active = False
    db.commit()
    return {"message": "Branch deactivated"}


# ── Warehouses ────────────────────────────────────────────────────────────────

@router.get("/warehouses/all", response_model=List[WarehouseResponse])
def list_warehouses(db: Session = Depends(get_db), current_user=Depends(require_branch_manager_or_above)):
    return db.query(Warehouse).filter(Warehouse.is_active == True).all()


@router.post("/warehouses/", response_model=WarehouseResponse)
def create_warehouse(data: WarehouseCreate, db: Session = Depends(get_db), current_user=Depends(require_admin)):
    wh = Warehouse(**data.model_dump())
    db.add(wh)
    db.commit()
    db.refresh(wh)
    return wh
