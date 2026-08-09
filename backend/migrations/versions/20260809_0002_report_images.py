"""store report images in the database

Revision ID: 20260809_0002
Revises: 20260808_0001
"""
from alembic import op
import sqlalchemy as sa

revision = '20260809_0002'
down_revision = '20260808_0001'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('report', sa.Column('image_data', sa.LargeBinary(), nullable=True))
    op.add_column('report', sa.Column('image_mime', sa.String(length=80), nullable=True))

def downgrade():
    op.drop_column('report', 'image_mime')
    op.drop_column('report', 'image_data')
